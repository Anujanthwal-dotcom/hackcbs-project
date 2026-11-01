'use client';

import React, { useEffect, useRef, useState, useCallback } from 'react';
import type { DetectionPoint, StateStat } from '../types';
import type { Feature, FeatureCollection, Geometry, Position } from 'geojson';
import type { LayerGroup, Map as LeafletMap, Path, TileLayer } from 'leaflet';
import {
  ZoomIn,
  ZoomOut,
  RotateCcw,
  Flame,
  X,
  MapPin,
  AlertTriangle,
} from 'lucide-react';

// Import Leaflet CSS directly at component level
import 'leaflet/dist/leaflet.css';

interface IndiaHeatmapMapProps {
  points: DetectionPoint[];
  selectedState: string;
  onSelectState: (stateName: string) => void;
  stateStats: StateStat[];
  selectedPoint?: DetectionPoint | null;
  onSelectPoint?: (point: DetectionPoint | null) => void;
}

const INDIA_CENTER: [number, number] = [22.5, 78.9];
const INDIA_ZOOM = 5;
const DISTRICT_BOUNDARIES_URL =
  'https://cdn.jsdelivr.net/gh/udit-001/india-maps-data@cc91a19/geojson/india.geojson';
type MapStyleType = 'canvas' | 'satellite' | 'topo';
type LeafletApi = typeof import('leaflet');
const MAP_TILE_URLS: Record<MapStyleType, { base: string; labels?: string }> = {
  canvas: {
    base: 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
    labels:
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
  },
  satellite: {
    base: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    labels:
      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
  },
  topo: {
    base: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
  },
};

type BoundaryFeatureCollection = FeatureCollection<Geometry, Record<string, unknown>>;
type DistrictFeature = Feature<Geometry, Record<string, unknown>>;

function buildStateBoundaryData(
  districtData: BoundaryFeatureCollection,
): BoundaryFeatureCollection {
  const stateFeatures = districtData.features
    .filter((feature) => !String(feature.properties?.district ?? '').trim())
    .map((feature) => ({
      ...feature,
      properties: {
        ...feature.properties,
        NAME_1: String(feature.properties?.st_nm ?? ''),
      },
    }));
  const statesWithOutlines = new Set(
    stateFeatures.map((feature) => String(feature.properties.NAME_1)),
  );
  const fallbackGeometries = new Map<string, Map<string, Geometry>>();

  for (const feature of districtData.features) {
    const stateName = String(feature.properties?.st_nm ?? '');
    if (!feature.properties?.district || !stateName || statesWithOutlines.has(stateName)) {
      continue;
    }

    const geometries = fallbackGeometries.get(stateName) ?? new Map();
    geometries.set(JSON.stringify(feature.geometry), feature.geometry);
    fallbackGeometries.set(stateName, geometries);
  }

  for (const [stateName, geometries] of fallbackGeometries) {
    const polygons = [...geometries.values()].flatMap((geometry) => {
      if (geometry.type === 'Polygon') return [geometry.coordinates];
      if (geometry.type === 'MultiPolygon') return geometry.coordinates;
      return [];
    });
    if (polygons.length === 0) continue;

    stateFeatures.push({
      type: 'Feature',
      properties: { NAME_1: stateName },
      geometry: { type: 'MultiPolygon', coordinates: polygons },
    });
  }

  return { type: 'FeatureCollection', features: stateFeatures };
}

function normalizeStateName(value: string) {
  return value.toLowerCase().replace(/[^a-z]/g, '');
}

function getStateForBoundaryName(name: string, stateStats: StateStat[]) {
  const normalizedName = normalizeStateName(name);
  return stateStats.find((state) => normalizeStateName(state.name) === normalizedName);
}

function getPointsForState(points: DetectionPoint[], state: StateStat | undefined) {
  if (!state) return [];
  return points.filter(
    (point) =>
      normalizeStateName(point.state) === normalizeStateName(state.name) ||
      (!point.state && point.stateCode.toLowerCase() === state.code.toLowerCase()),
  );
}

function getFeaturesForState(
  features: DistrictFeature[],
  state: StateStat | undefined,
  stateName: string,
) {
  const acceptedNames = new Set([normalizeStateName(state?.name ?? stateName)]);
  return features.filter(
    (feature) =>
      Boolean(feature.properties?.district) &&
      acceptedNames.has(
        normalizeStateName(String(feature.properties?.st_nm ?? '')),
      ),
  );
}

function getStateBoundaryFeatures(
  features: DistrictFeature[],
  state: StateStat | undefined,
  stateName: string,
) {
  const acceptedNames = new Set([normalizeStateName(state?.name ?? stateName)]);
  return features.filter((feature) =>
    acceptedNames.has(normalizeStateName(String(feature.properties?.NAME_1 ?? ''))),
  );
}

function pointInRing(longitude: number, latitude: number, ring: Position[]) {
  let inside = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [currentLongitude, currentLatitude] = ring[i];
    const [previousLongitude, previousLatitude] = ring[j];
    const crossesLatitude =
      (currentLatitude > latitude) !== (previousLatitude > latitude);
    if (
      crossesLatitude &&
      longitude <
        ((previousLongitude - currentLongitude) *
          (latitude - currentLatitude)) /
          (previousLatitude - currentLatitude) +
          currentLongitude
    ) {
      inside = !inside;
    }
  }
  return inside;
}

function pointInPolygon(
  point: DetectionPoint,
  rings: Position[][],
) {
  return (
    rings.length > 0 &&
    pointInRing(point.longitude, point.latitude, rings[0]) &&
    !rings.slice(1).some((ring) => pointInRing(point.longitude, point.latitude, ring))
  );
}

function pointInStateGeometry(point: DetectionPoint, features: DistrictFeature[]) {
  return features.some((feature) => {
    if (feature.geometry.type === 'Polygon') {
      return pointInPolygon(point, feature.geometry.coordinates);
    }
    if (feature.geometry.type === 'MultiPolygon') {
      return feature.geometry.coordinates.some((polygon) => pointInPolygon(point, polygon));
    }
    return false;
  });
}

function getPointsWithinState(
  points: DetectionPoint[],
  state: StateStat | undefined,
  features: DistrictFeature[],
  stateName: string,
) {
  const statePoints = getPointsForStateName(points, stateName, state);
  if (features.length === 0) return statePoints;
  return statePoints.filter((point) => pointInStateGeometry(point, features));
}

function getPointsForStateName(
  points: DetectionPoint[],
  stateName: string,
  state: StateStat | undefined,
) {
  if (state) return getPointsForState(points, state);
  const normalizedName = normalizeStateName(stateName);
  return points.filter(
    (point) => normalizeStateName(point.state) === normalizedName,
  );
}

function getStateColor(value: number, maxValue: number) {
  if (value <= 0) return '#edf1e8';
  const ratio = maxValue > 0 ? value / maxValue : 0;
  if (ratio <= 0.25) return '#fee2d5';
  if (ratio <= 0.5) return '#fca77c';
  if (ratio <= 0.75) return '#e6634a';
  return '#9f2d27';
}

function getSeverityColor(severity: DetectionPoint['severity']) {
  switch (severity) {
    case 'CRITICAL':
      return '#9f2d27';
    case 'HIGH':
      return '#e6634a';
    case 'MEDIUM':
      return '#f59e0b';
    default:
      return '#84a653';
  }
}

export default function IndiaHeatmapMap({
  points,
  selectedState,
  onSelectState,
  stateStats,
  selectedPoint,
  onSelectPoint,
}: IndiaHeatmapMapProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const expandedMapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<{
    instance: LeafletMap;
    heatGroup: LayerGroup;
    stateGroup: LayerGroup;
    baseTile: TileLayer;
    labelTile: TileLayer | null;
    style: MapStyleType;
    L: LeafletApi;
  } | null>(null);
  const expandedMapRef = useRef<{ instance: LeafletMap; L: LeafletApi } | null>(null);

  const [mapReady, setMapReady] = useState(false);
  const [mapStyle, setMapStyle] = useState<MapStyleType>('canvas');
  const [radiusScale, setRadiusScale] = useState<number>(1.0); // 0.6x (Local), 1.0x (Standard), 1.6x (Regional)
  const showPulseAnimation = true;
  const [boundaryData, setBoundaryData] = useState<BoundaryFeatureCollection | null>(null);
  const [stateBoundaryData, setStateBoundaryData] = useState<BoundaryFeatureCollection | null>(null);
  const [boundaryError, setBoundaryError] = useState<string | null>(null);
  const [expandedState, setExpandedState] = useState<string | null>(null);
  const [isBoundaryLoading, setIsBoundaryLoading] = useState(true);

  const loadBoundaries = useCallback(async () => {
    setIsBoundaryLoading(true);
    setBoundaryError(null);
    try {
      const districtResponse = await fetch(DISTRICT_BOUNDARIES_URL);
      if (!districtResponse.ok) {
        throw new Error(`Boundary data request failed: ${districtResponse.status}`);
      }
      const districtData =
        (await districtResponse.json()) as BoundaryFeatureCollection;
      if (
        districtData.type !== 'FeatureCollection' ||
        !Array.isArray(districtData.features)
      ) {
        throw new Error('Boundary data has an unexpected format');
      }
      setBoundaryData(districtData);
      setStateBoundaryData(buildStateBoundaryData(districtData));
    } catch (error) {
      console.error('[IndiaHeatmapMap] Failed to load district boundaries.', error);
      setBoundaryError('Administrative boundaries could not be loaded. Retry to view the state heatmap.');
    } finally {
      setIsBoundaryLoading(false);
    }
  }, []);

  useEffect(() => {
    const request = window.setTimeout(() => void loadBoundaries(), 0);
    return () => window.clearTimeout(request);
  }, [loadBoundaries]);

  useEffect(() => {
    const updateSelection = window.requestAnimationFrame(() => {
      setExpandedState(selectedState === 'ALL' ? null : selectedState);
    });
    return () => window.cancelAnimationFrame(updateSelection);
  }, [selectedState]);

  useEffect(() => {
    if (!expandedState) return;
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setExpandedState(null);
    };
    window.addEventListener('keydown', closeOnEscape);
    return () => window.removeEventListener('keydown', closeOnEscape);
  }, [expandedState]);

  // ── 1. Initialize the Leaflet map once ─────────────────────────────────────
  useEffect(() => {
    if (mapRef.current || !mapContainerRef.current) return;

    let cancelled = false;

    (async () => {
      const L = (await import('leaflet')).default;

      if (cancelled || !mapContainerRef.current || mapRef.current) return;

      const map = L.map(mapContainerRef.current, {
        center: INDIA_CENTER,
        zoom: INDIA_ZOOM,
        minZoom: 4,
        maxZoom: 16,
        zoomControl: false,
        attributionControl: false,
        preferCanvas: true,
      });

      // Free, open Esri Light Gray Canvas tiles
      const baseTile = L.tileLayer(
        'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
        { maxZoom: 16, attribution: '© Esri' },
      ).addTo(map);

      // Label overlay
      const labelTile = L.tileLayer(
        MAP_TILE_URLS.canvas.labels!,
        { maxZoom: 16, opacity: 0.85 },
      ).addTo(map);

      const stateGroup = L.layerGroup().addTo(map);
      // Dedicated layer group for all red heat halos and pulse markers
      const heatGroup = L.layerGroup().addTo(map);

      mapRef.current = {
        instance: map,
        heatGroup,
        stateGroup,
        baseTile,
        labelTile,
        style: 'canvas',
        L,
      };

      // Invalidate size to ensure full dimensions render cleanly
      setTimeout(() => {
        if (!cancelled && mapRef.current) {
          map.invalidateSize();
          setMapReady(true);
        }
      }, 60);
    })();

    return () => {
      cancelled = true;
      if (mapRef.current) {
        mapRef.current.instance.stop();
        mapRef.current.instance.remove();
        mapRef.current = null;
      }
      setMapReady(false);
    };
  }, []);

  // ── 2. Render the state choropleth from recorded case totals ────────────────
  useEffect(() => {
    if (!mapReady || !mapRef.current || !boundaryData || !stateBoundaryData) return;

    const { stateGroup, L } = mapRef.current;
    stateGroup.clearLayers();
    const stateCaseCounts = new Map<string, number>();
    for (const state of stateStats) {
      stateCaseCounts.set(state.code, getPointsForState(points, state).length);
    }
    for (const point of points) {
      const state = stateStats.find(
        (candidate) =>
          normalizeStateName(candidate.name) === normalizeStateName(point.state) ||
          (!point.state &&
            candidate.code.toLowerCase() === point.stateCode.toLowerCase()),
      );
      const key = state?.code ?? normalizeStateName(point.state);
      if (!stateCaseCounts.has(key)) stateCaseCounts.set(key, 0);
      stateCaseCounts.set(key, (stateCaseCounts.get(key) ?? 0) + (state ? 0 : 1));
    }
    const maxCases = Math.max(...stateCaseCounts.values(), 1);
    const districtFeatures = boundaryData.features.filter((feature) =>
      Boolean(feature.properties?.district),
    );

    L.geoJSON(
      { type: 'FeatureCollection', features: districtFeatures } as Parameters<
        typeof L.geoJSON
      >[0],
      {
        style: (feature: { properties?: Record<string, unknown> } | undefined) => {
          const name = String(feature?.properties?.st_nm ?? '');
          const stat = getStateForBoundaryName(name, stateStats);
          const count = stat
            ? stateCaseCounts.get(stat.code)
            : stateCaseCounts.get(normalizeStateName(name));
          return {
            color: '#77836f',
            weight: 0.5,
            opacity: 0.48,
            fillColor:
              count !== undefined ? getStateColor(count, maxCases) : '#e8ece4',
            fillOpacity: 0.82,
          };
        },
      },
    ).addTo(stateGroup);

    const stateLayer = L.geoJSON(
      { type: 'FeatureCollection', features: stateBoundaryData.features } as Parameters<
        typeof L.geoJSON
      >[0],
      {
        style: (feature: { properties?: Record<string, unknown> } | undefined) => {
          const geoName = String(feature?.properties?.NAME_1 ?? '');
          const stat = getStateForBoundaryName(geoName, stateStats);
          const isSelected =
            normalizeStateName(selectedState) === normalizeStateName(geoName) ||
            (stat !== undefined &&
              normalizeStateName(selectedState) === normalizeStateName(stat.name));
          return {
            color: isSelected ? '#203a1b' : '#40543a',
            weight: isSelected ? 2.8 : 1.8,
            opacity: 0.96,
            fill: false,
          };
        },
        onEachFeature: (feature, featureLayer) => {
          const geoName = String(feature.properties?.NAME_1 ?? '');
          const stat = getStateForBoundaryName(geoName, stateStats);
          const displayName = stat?.name ?? geoName;
          const caseCount = stat
            ? stateCaseCounts.get(stat.code)
            : stateCaseCounts.get(normalizeStateName(geoName));
          const path = featureLayer as Path;

          path.bindTooltip(
            caseCount === undefined
              ? `<strong>${displayName}</strong><br/>No metric data available`
              : `<strong>${displayName}</strong><br/>${caseCount} confirmed detections`,
            { sticky: true, className: 'state-heatmap-tooltip' },
          );
          path.on({
            mouseover: () => {
              path.setStyle({ color: '#27421d', weight: 3.2, opacity: 1 });
              path.bringToFront();
            },
            mouseout: () => stateLayer.resetStyle(path),
            click: () => {
              onSelectState(displayName);
              setExpandedState(displayName);
            },
          });
        },
      },
    ).addTo(stateGroup);

    return () => {
      stateGroup.clearLayers();
    };
  }, [
    boundaryData,
    mapReady,
    onSelectState,
    points,
    selectedState,
    stateBoundaryData,
    stateStats,
  ]);

  // ── 3. Render red heat patches and pulse markers ──────────────────────────
  useEffect(() => {
    if (!mapReady || !mapRef.current) return;

    const { heatGroup, L } = mapRef.current;
    if (!heatGroup || !L) return;

    heatGroup.clearLayers();

    points.forEach((point) => {
      if (
        typeof point.latitude !== 'number' ||
        typeof point.longitude !== 'number' ||
        isNaN(point.latitude) ||
        isNaN(point.longitude)
      ) {
        return;
      }

      const isCritical = point.severity === 'CRITICAL';
      const isHigh = point.severity === 'HIGH';

      // Diffusion radii in meters, scaled by user setting
      const baseR1 = isCritical ? 85000 : isHigh ? 58000 : 38000;
      const baseR2 = isCritical ? 45000 : isHigh ? 30000 : 19000;
      const baseR3 = isCritical ? 22000 : isHigh ? 15000 : 9500;

      const r1 = Math.round(baseR1 * radiusScale);
      const r2 = Math.round(baseR2 * radiusScale);
      const r3 = Math.round(baseR3 * radiusScale);

      // Layer 1: Outer diffused heat halo
      L.circle([point.latitude, point.longitude], {
        radius: r1,
        stroke: false,
        fillColor: '#DC2626',
        fillOpacity: isCritical ? 0.20 : 0.12,
        interactive: false,
      }).addTo(heatGroup);

      // Layer 2: Mid-intensity contagion zone
      L.circle([point.latitude, point.longitude], {
        radius: r2,
        stroke: false,
        fillColor: '#B91C1C',
        fillOpacity: isCritical ? 0.44 : 0.28,
        interactive: false,
      }).addTo(heatGroup);

      // Layer 3: Dense epicenter core
      L.circle([point.latitude, point.longitude], {
        radius: r3,
        stroke: false,
        fillColor: '#991B1B',
        fillOpacity: isCritical ? 0.76 : 0.54,
        interactive: false,
      }).addTo(heatGroup);

      // Pulse pin marker
      const pinColor = isCritical ? '#C62828' : isHigh ? '#EA580C' : '#D97706';
      const isSelected = selectedPoint && selectedPoint.id === point.id;

      const markerHtml = `
        <div class="heat-pulse-marker ${isSelected ? 'ring-2 ring-white scale-125' : ''}">
          ${showPulseAnimation && isCritical ? '<div class="pulse-ring"></div>' : ''}
          <div class="core-dot" style="background-color: ${pinColor}; ${
            isSelected ? 'box-shadow: 0 0 16px #ffffff, 0 0 8px #C62828;' : ''
          }"></div>
        </div>`;

      const icon = L.divIcon({
        className: 'outbreak-custom-pin',
        html: markerHtml,
        iconSize: [24, 24],
        iconAnchor: [12, 12],
      });

      const marker = L.marker([point.latitude, point.longitude], { icon })
        .addTo(heatGroup)
        .on('click', () => {
          if (onSelectPoint) {
            onSelectPoint(point);
          }
        });

      // Rich hover/click popup
      const popupHtml = `
        <div style="font-family: inherit; min-width: 210px; padding: 4px;">
          <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 6px;">
            <span style="font-size: 11px; font-weight: 800; text-transform: uppercase; padding: 2px 8px; border-radius: 9999px; background: ${
              isCritical ? '#FEE2E2' : '#FEF3C7'
            }; color: ${isCritical ? '#991B1B' : '#92400E'};">
              ${point.severity}
            </span>
            <span style="font-size: 11px; color: #5A7250; font-weight: 700;">
              ${(point.confidence * 100).toFixed(1)}% AI Confirmed
            </span>
          </div>
          <div style="font-size: 15px; font-weight: 800; color: #27421D; margin-bottom: 2px;">
            ${point.crop} · ${point.condition}
          </div>
          <div style="font-size: 12px; color: #5A7250; margin-bottom: 6px;">
            📍 ${point.district}, ${point.state}
          </div>
          <div style="font-size: 11px; color: #27421D; background: #F3F5EA; padding: 6px 8px; border-radius: 8px;">
            GPS: <strong>${point.latitude.toFixed(4)}, ${point.longitude.toFixed(4)}</strong>
          </div>
        </div>
      `;

      marker.bindPopup(popupHtml, {
        closeButton: false,
        className: 'custom-outbreak-popup',
      });
    });
  }, [points, mapReady, radiusScale, showPulseAnimation, selectedPoint, onSelectPoint]);

  // ── 4. Smooth flyTo when state changes ─────────────────────────────────────
  useEffect(() => {
    if (!mapReady || !mapRef.current) return;
    const map = mapRef.current.instance;

    if (selectedState === 'ALL') {
      map.flyTo(INDIA_CENTER, INDIA_ZOOM, { duration: 1.2 });
      return;
    }

    const matched = stateStats.find(
      (s) =>
        s.name.toLowerCase() === selectedState.toLowerCase() ||
        s.code.toLowerCase() === selectedState.toLowerCase(),
    );

    if (matched?.center) {
      map.flyTo([matched.center.lat, matched.center.lng], matched.zoom || 7, {
        duration: 1.2,
      });
    }
  }, [selectedState, stateStats, mapReady]);

  // ── 5. Zoom to selectedPoint if set externally ────────────────────────────
  useEffect(() => {
    if (!mapReady || !mapRef.current || !selectedPoint) return;
    const map = mapRef.current.instance;
    map.flyTo([selectedPoint.latitude, selectedPoint.longitude], 10, {
      duration: 1.0,
    });
  }, [selectedPoint, mapReady]);

  // ── 6. Change Map Style (Canvas / Satellite / Topographic) ────────────────
  const handleSetStyle = useCallback((nextStyle: MapStyleType) => {
    if (!mapRef.current) return;
    const { instance: map, baseTile, labelTile, L } = mapRef.current;

    setMapStyle(nextStyle);
    mapRef.current.style = nextStyle;

    if (baseTile) map.removeLayer(baseTile);
    if (labelTile) map.removeLayer(labelTile);

    if (nextStyle === 'satellite') {
      // Free Esri World Imagery (Satellite)
      mapRef.current.baseTile = L.tileLayer(
        MAP_TILE_URLS.satellite.base,
        { maxZoom: 17, attribution: '© Esri Satellite' },
      ).addTo(map);

      // Add reference label overlay so state/city names stay readable on imagery
      mapRef.current.labelTile = L.tileLayer(
        MAP_TILE_URLS.satellite.labels!,
        { maxZoom: 17, opacity: 0.9 },
      ).addTo(map);
    } else if (nextStyle === 'topo') {
      // Free Esri World Topo Map
      mapRef.current.baseTile = L.tileLayer(
        MAP_TILE_URLS.topo.base,
        { maxZoom: 16, attribution: '© Esri Topo' },
      ).addTo(map);
      mapRef.current.labelTile = null;
    } else {
      // Canvas Light Gray Base
      mapRef.current.baseTile = L.tileLayer(
        MAP_TILE_URLS.canvas.base,
        { maxZoom: 16, attribution: '© Esri Canvas' },
      ).addTo(map);
      mapRef.current.labelTile = L.tileLayer(
        MAP_TILE_URLS.canvas.labels!,
        { maxZoom: 16, opacity: 0.85 },
      ).addTo(map);
    }
  }, []);

  // ── 7. Render the expanded state view with district lines and actual cases ──
  useEffect(() => {
    if (
      !expandedState ||
      !expandedMapContainerRef.current ||
      !boundaryData ||
      !stateBoundaryData
    ) return;

    let cancelled = false;
    let timeout: ReturnType<typeof setTimeout>;

    (async () => {
      const L = (await import('leaflet')).default;
      if (cancelled || !expandedMapContainerRef.current) return;

      if (expandedMapRef.current) {
        expandedMapRef.current.instance.stop();
        expandedMapRef.current.instance.remove();
        expandedMapRef.current = null;
      }
      const detailMap = L.map(expandedMapContainerRef.current, {
        center: INDIA_CENTER,
        zoom: 6,
        minZoom: 5,
        maxZoom: 16,
        zoomControl: false,
        attributionControl: false,
        preferCanvas: false,
        scrollWheelZoom: true,
      });

      const selectedTile = MAP_TILE_URLS[mapStyle];
      L.tileLayer(selectedTile.base, {
        maxZoom: mapStyle === 'satellite' ? 17 : 16,
        attribution: '© Esri',
      }).addTo(detailMap);
      if (selectedTile.labels) {
        L.tileLayer(selectedTile.labels, { maxZoom: 17, opacity: 0.85 }).addTo(detailMap);
      }

      const selectedStat =
        stateStats.find(
          (stat) =>
            stat.name.toLowerCase() === expandedState.toLowerCase() ||
            stat.code.toLowerCase() === expandedState.toLowerCase(),
        ) ?? getStateForBoundaryName(expandedState, stateStats);
      const selectedFeatures = getFeaturesForState(
        boundaryData.features,
        selectedStat,
        expandedState,
      );
      const selectedStateFeatures = getStateBoundaryFeatures(
        stateBoundaryData.features,
        selectedStat,
        expandedState,
      );
      const maxCases = Math.max(
        ...stateStats.map((stat) => getPointsForState(points, stat).length),
        1,
      );
      const selectedCaseCount = getPointsForStateName(
        points,
        expandedState,
        selectedStat,
      ).length;
      const districtLayer = L.geoJSON(
        { type: 'FeatureCollection', features: selectedFeatures } as Parameters<
          typeof L.geoJSON
        >[0],
        {
          style: {
            color: '#76836f',
            weight: 0.7,
            opacity: 0.7,
            fillColor: getStateColor(selectedCaseCount, maxCases),
            fillOpacity: 0.16,
          },
          onEachFeature: (feature, featureLayer) => {
            const district = String(feature.properties?.district ?? '');
            if (district) {
              (featureLayer as Path).bindTooltip(district, {
                sticky: true,
                className: 'state-heatmap-tooltip',
              });
            }
          },
        },
      ).addTo(detailMap);
      const stateBoundary = L.geoJSON(
        { type: 'FeatureCollection', features: selectedStateFeatures } as Parameters<
          typeof L.geoJSON
        >[0],
        {
          style: {
            color: '#203a1b',
            weight: 3,
            opacity: 1,
            fillColor: getStateColor(selectedCaseCount, maxCases),
            fillOpacity: 0.28,
          },
        },
      ).addTo(detailMap);

      const statePoints = getPointsWithinState(
        points,
        selectedStat,
        selectedFeatures,
        expandedState,
      );
      const heatLayer = L.layerGroup().addTo(detailMap);
      statePoints.forEach((point) => {
        const weight =
          point.severity === 'CRITICAL'
            ? 1
            : point.severity === 'HIGH'
              ? 0.75
              : point.severity === 'MEDIUM'
                ? 0.5
                : 0.35;
        const color = getSeverityColor(point.severity);
        L.circle([point.latitude, point.longitude], {
          radius: Math.round((18000 + weight * 42000) * radiusScale),
          color,
          weight: 1,
          opacity: 0.55,
          fillColor: color,
          fillOpacity: 0.16 + weight * 0.28,
          interactive: false,
        }).addTo(heatLayer);
        L.circleMarker([point.latitude, point.longitude], {
          radius: 5 + weight * 3,
          color: '#fff',
          weight: 1.5,
          fillColor: color,
          fillOpacity: 1,
        })
          .bindTooltip(
            `${point.crop} · ${point.condition}<br/>${point.severity} · ${(point.confidence * 100).toFixed(0)}% confidence`,
          )
          .addTo(heatLayer);
      });

      expandedMapRef.current = { instance: detailMap, L };
      timeout = setTimeout(() => {
        if (cancelled) return;
        detailMap.invalidateSize();
        const stateBounds = stateBoundary.getBounds();
        const districtBounds = districtLayer.getBounds();
        if (stateBounds.isValid()) {
          detailMap.fitBounds(stateBounds, { padding: [24, 24], animate: false });
        } else if (districtBounds.isValid()) {
          detailMap.fitBounds(districtBounds, {
            padding: [24, 24],
            animate: false,
          });
        } else if (selectedStat?.center) {
          detailMap.setView([selectedStat.center.lat, selectedStat.center.lng], 7);
        }
      }, 80);
    })();

    return () => {
      cancelled = true;
      clearTimeout(timeout);
      if (expandedMapRef.current) {
        expandedMapRef.current.instance.stop();
        expandedMapRef.current.instance.remove();
        expandedMapRef.current = null;
      }
    };
  }, [
    boundaryData,
    expandedState,
    mapStyle,
    points,
    radiusScale,
    stateBoundaryData,
    stateStats,
  ]);

  const handleZoomIn = () => mapRef.current?.instance.zoomIn();
  const handleZoomOut = () => mapRef.current?.instance.zoomOut();
  const handleReset = () => {
    onSelectState('ALL');
    if (onSelectPoint) onSelectPoint(null);
    mapRef.current?.instance.flyTo(INDIA_CENTER, INDIA_ZOOM, { duration: 1.2 });
  };

  const expandedStat =
    stateStats.find(
      (stat) =>
        stat.name.toLowerCase() === expandedState?.toLowerCase() ||
        stat.code.toLowerCase() === expandedState?.toLowerCase(),
    ) ?? getStateForBoundaryName(expandedState ?? '', stateStats);
  const expandedFeatures = boundaryData
    ? getFeaturesForState(boundaryData.features, expandedStat, expandedState ?? '')
    : [];
  const expandedPoints = getPointsWithinState(
    points,
    expandedStat,
    expandedFeatures,
    expandedState ?? '',
  );
  const stateCaseCounts = stateStats.map((state) => ({
    state,
    count: getPointsForState(points, state).length,
  }));
  const otherStateCounts = new Map<string, number>();
  for (const point of points) {
    if (
      stateStats.some(
        (state) =>
          normalizeStateName(state.name) === normalizeStateName(point.state),
      )
    ) {
      continue;
    }
    const key = normalizeStateName(point.state);
    otherStateCounts.set(key, (otherStateCounts.get(key) ?? 0) + 1);
  }
  const maxCases = Math.max(
    ...stateCaseCounts.map(({ count }) => count),
    ...otherStateCounts.values(),
    1,
  );
  const getTopValues = (values: string[]) => [...new Set(values)].slice(0, 3);

  return (
    <div className="relative w-full h-[600px] rounded-3xl overflow-hidden border border-[#E2E9D4] shadow-sm bg-[#F3F5EA]">
      {/* 2D Leaflet Map Container */}
      <div
        ref={mapContainerRef}
        tabIndex={0}
        role="region"
        aria-label="Agricultural Outbreak Hotspot 2D Map"
        className="w-full h-full"
        style={{ cursor: 'grab' }}
      />

      {/* Top Left: State case-count legend */}
      <div className="absolute top-4 left-4 z-[500] bg-[#FAFCF5]/95 backdrop-blur-md px-4 py-3 rounded-2xl border border-[#E2E9D4] shadow-md flex flex-col gap-2 pointer-events-auto">
        <div className="flex items-center gap-2">
          <div className="w-2.5 h-2.5 rounded-full bg-[#C62828]" />
          <span className="text-xs font-bold text-[#27421D] tracking-wide uppercase">
            State detections
          </span>
        </div>
        <div className="flex items-center gap-1.5 pt-1 border-t border-[#E2E9D4]/60">
          {[
            { value: 0, label: '0' },
            { value: maxCases * 0.25, label: 'Low' },
            { value: maxCases * 0.5, label: 'Moderate' },
            { value: maxCases * 0.75, label: 'High' },
            { value: maxCases, label: 'Very high' },
          ].map((stop) => (
            <div key={stop.label} className="flex flex-col items-center gap-1">
              <span
                className="w-7 h-2 rounded-sm border border-white/70"
                style={{ backgroundColor: getStateColor(stop.value, maxCases) }}
              />
              <span className="text-[9px] text-[#5A7250]">{stop.label}</span>
            </div>
          ))}
        </div>
        <div className="text-[10px] text-[#5A7250]">
          {points.length} filtered detections · max {maxCases} per state
        </div>
        <div className="text-[9px] leading-relaxed text-[#5A7250]">
          Dark outline: state · thin lines: districts
          <br />
          Neutral fill: no metric data
        </div>
      </div>

      {/* Top Right: State Pill Selector & Layer Switcher */}
      <div className="absolute top-4 right-4 z-[500] flex flex-wrap items-center gap-2 pointer-events-auto max-w-[90vw] justify-end">
        {/* State Zoom Pills */}
        <div className="bg-[#FAFCF5]/95 backdrop-blur-md p-1.5 rounded-2xl border border-[#E2E9D4] shadow-md flex items-center gap-1 overflow-x-auto max-w-full">
          <button
            onClick={handleReset}
            className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all whitespace-nowrap ${
              selectedState === 'ALL'
                ? 'bg-[#27421D] text-white shadow-xs'
                : 'text-[#27421D] hover:bg-[#DCE9C7]'
            }`}
          >
            All India
          </button>
          {stateStats.slice(0, 4).map((st) => (
            <button
              key={st.id}
              onClick={() => {
                onSelectState(st.name);
                setExpandedState(st.name);
              }}
              className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition-all whitespace-nowrap ${
                selectedState.toLowerCase() === st.name.toLowerCase()
                  ? 'bg-[#27421D] text-white shadow-xs'
                  : 'text-[#27421D] hover:bg-[#DCE9C7]'
              }`}
            >
              {st.name} ({stateCaseCounts.find(({ state }) => state.id === st.id)?.count ?? 0})
            </button>
          ))}
        </div>

        {/* Map Layer Style Pills */}
        <div className="bg-[#FAFCF5]/95 backdrop-blur-md p-1.5 rounded-2xl border border-[#E2E9D4] shadow-md flex items-center gap-1">
          <button
            onClick={() => handleSetStyle('canvas')}
            title="Clean Light Canvas view"
            className={`px-2.5 py-1.5 rounded-xl text-xs font-semibold transition-all ${
              mapStyle === 'canvas'
                ? 'bg-[#27421D] text-white'
                : 'text-[#27421D] hover:bg-[#DCE9C7]'
            }`}
          >
            Canvas
          </button>
          <button
            onClick={() => handleSetStyle('satellite')}
            title="Satellite Imagery to see actual farmlands"
            className={`px-2.5 py-1.5 rounded-xl text-xs font-semibold transition-all ${
              mapStyle === 'satellite'
                ? 'bg-[#27421D] text-white'
                : 'text-[#27421D] hover:bg-[#DCE9C7]'
            }`}
          >
            Satellite
          </button>
          <button
            onClick={() => handleSetStyle('topo')}
            title="Topographic terrain view"
            className={`px-2.5 py-1.5 rounded-xl text-xs font-semibold transition-all ${
              mapStyle === 'topo'
                ? 'bg-[#27421D] text-white'
                : 'text-[#27421D] hover:bg-[#DCE9C7]'
            }`}
          >
            Topo
          </button>
        </div>
      </div>

      {/* Bottom Left: Controls for Heat Patch Radius Scale & Radar Animation */}
      <div className="absolute bottom-5 left-5 z-[500] flex flex-wrap items-center gap-2 pointer-events-auto">
        <div className="bg-[#FAFCF5]/95 backdrop-blur-md px-3 py-2 rounded-2xl border border-[#E2E9D4] shadow-md flex items-center gap-2 text-xs text-[#27421D] font-semibold">
          <Flame className="w-3.5 h-3.5 text-[#C62828]" />
          <span>Heat Halo:</span>
          <button
            onClick={() => setRadiusScale(0.6)}
            className={`px-2 py-0.5 rounded-lg text-[11px] transition-colors ${
              radiusScale === 0.6 ? 'bg-[#27421D] text-white' : 'hover:bg-[#DCE9C7]'
            }`}
          >
            Local
          </button>
          <button
            onClick={() => setRadiusScale(1.0)}
            className={`px-2 py-0.5 rounded-lg text-[11px] transition-colors ${
              radiusScale === 1.0 ? 'bg-[#27421D] text-white' : 'hover:bg-[#DCE9C7]'
            }`}
          >
            Standard
          </button>
          <button
            onClick={() => setRadiusScale(1.6)}
            className={`px-2 py-0.5 rounded-lg text-[11px] transition-colors ${
              radiusScale === 1.6 ? 'bg-[#27421D] text-white' : 'hover:bg-[#DCE9C7]'
            }`}
          >
            Regional
          </button>
        </div>

        {selectedState !== 'ALL' && (
          <div className="bg-[#27421D] text-white px-4 py-2 rounded-2xl shadow-lg border border-[#DCE9C7]/30 flex items-center gap-3">
            <div className="flex flex-col">
              <span className="text-[9px] text-[#DCE9C7] uppercase font-bold tracking-wider">
                Active Region
              </span>
              <span className="text-xs font-bold">{selectedState}</span>
            </div>
            <button
              onClick={handleReset}
              className="text-xs bg-white/20 hover:bg-white/30 text-white font-semibold px-2 py-0.5 rounded-lg transition-colors"
            >
              ← All
            </button>
          </div>
        )}
      </div>

      {/* Bottom Right: Zoom & Center Controls */}
      <div className="absolute bottom-5 right-5 z-[500] flex flex-col gap-2 pointer-events-auto">
        <button
          onClick={handleZoomIn}
          title="Zoom In"
          className="w-10 h-10 rounded-2xl bg-[#FAFCF5] hover:bg-[#DCE9C7] text-[#27421D] border border-[#E2E9D4] shadow-md flex items-center justify-center transition-transform active:scale-95"
        >
          <ZoomIn className="w-4 h-4" />
        </button>
        <button
          onClick={handleZoomOut}
          title="Zoom Out"
          className="w-10 h-10 rounded-2xl bg-[#FAFCF5] hover:bg-[#DCE9C7] text-[#27421D] border border-[#E2E9D4] shadow-md flex items-center justify-center transition-transform active:scale-95"
        >
          <ZoomOut className="w-4 h-4" />
        </button>
        <button
          onClick={handleReset}
          title="Reset to All-India View"
          className="w-10 h-10 rounded-2xl bg-[#FAFCF5] hover:bg-[#DCE9C7] text-[#27421D] border border-[#E2E9D4] shadow-md flex items-center justify-center transition-transform active:scale-95"
        >
          <RotateCcw className="w-4 h-4" />
        </button>
      </div>

      {/* Loading Overlay */}
      {!mapReady && (
        <div className="absolute inset-0 z-[600] bg-[#F3F5EA]/85 backdrop-blur-xs flex flex-col items-center justify-center gap-3 rounded-3xl">
          <div className="w-10 h-10 border-4 border-[#27421D] border-t-transparent rounded-full animate-spin" />
          <span className="text-sm font-semibold text-[#27421D]">
            Loading 2D Surveillance Grid...
          </span>
        </div>
      )}

      {isBoundaryLoading && mapReady && (
        <div className="absolute bottom-5 left-1/2 z-[500] -translate-x-1/2 rounded-xl border border-[#E2E9D4] bg-[#FAFCF5]/95 px-3 py-2 text-xs font-medium text-[#5A7250] shadow">
          Loading state and district boundaries…
        </div>
      )}
      {boundaryError && (
        <div className="absolute bottom-5 left-1/2 z-[500] flex -translate-x-1/2 items-center gap-3 rounded-xl border border-[#F2C5B7] bg-[#FFF8F4] px-3 py-2 text-xs text-[#7D2C24] shadow">
          <span>{boundaryError}</span>
          <button
            onClick={() => void loadBoundaries()}
            className="font-bold underline"
          >
            Retry
          </button>
        </div>
      )}

      {expandedState && (
        <div
          className="fixed inset-0 z-[1200] flex items-center justify-center bg-[#152014]/65 p-3 backdrop-blur-sm sm:p-6"
          onClick={() => setExpandedState(null)}
          role="presentation"
        >
          <section
            className="state-detail-panel flex max-h-[94vh] w-full max-w-6xl flex-col overflow-hidden rounded-3xl border border-[#E2E9D4] bg-[#FAFCF5] shadow-2xl"
            role="dialog"
            aria-modal="true"
            aria-labelledby="state-detail-title"
            onClick={(event) => event.stopPropagation()}
          >
            <header className="flex flex-wrap items-start justify-between gap-4 border-b border-[#E2E9D4] px-5 py-4 sm:px-7">
              <div>
                <div className="mb-1 flex items-center gap-2 text-[10px] font-bold uppercase tracking-[0.16em] text-[#71836a]">
                  <MapPin className="h-3.5 w-3.5" />
                  State surveillance · district boundaries
                </div>
                <h2
                  id="state-detail-title"
                  className="text-xl font-black tracking-tight text-[#27421D] sm:text-2xl"
                >
                  {expandedStat?.name ?? expandedState}
                </h2>
                <p className="mt-1 text-xs text-[#5A7250]">
                  {expandedPoints.length} detections in the current dashboard view
                  {expandedPoints.length
                    ? ` · ${expandedPoints.filter((point) => point.severity === 'CRITICAL').length} critical`
                    : ''}
                  {getTopValues(expandedPoints.map((point) => point.crop)).length
                    ? ` · Crops: ${getTopValues(expandedPoints.map((point) => point.crop)).join(', ')}`
                    : ''}
                </p>
              </div>
              <div className="flex items-center gap-2">
                <select
                  value={expandedStat?.name ?? expandedState}
                  onChange={(event) => {
                    onSelectState(event.target.value);
                    setExpandedState(event.target.value);
                  }}
                  aria-label="Select state to view"
                  className="max-w-40 rounded-xl border border-[#E2E9D4] bg-white px-2.5 py-2 text-xs font-semibold text-[#27421D] sm:max-w-52"
                >
                  {(stateBoundaryData?.features ?? []).map((feature) => {
                    const name = String(feature.properties?.NAME_1 ?? '');
                    const state = getStateForBoundaryName(name, stateStats);
                    const value = state?.name ?? name;
                    return (
                      <option key={name} value={value}>
                        {value}
                      </option>
                    );
                  })}
                </select>
                <button
                  onClick={() => setExpandedState(null)}
                  aria-label="Close state heatmap"
                  className="flex h-10 w-10 items-center justify-center rounded-xl border border-[#E2E9D4] text-[#27421D] transition-colors hover:bg-[#DCE9C7]"
                >
                  <X className="h-5 w-5" />
                </button>
              </div>
            </header>

            <div className="grid min-h-0 flex-1 grid-cols-1 overflow-y-auto lg:grid-cols-[minmax(0,1fr)_250px]">
              <div className="relative min-h-[48vh] bg-[#F3F5EA] sm:min-h-[60vh]">
                <div
                  ref={expandedMapContainerRef}
                  className="absolute inset-0"
                  role="region"
                  aria-label={`${expandedStat?.name ?? expandedState} district heatmap`}
                />
                <div className="absolute bottom-4 left-4 z-[500] rounded-xl border border-[#E2E9D4] bg-[#FAFCF5]/95 px-3 py-2 shadow">
                  <div className="mb-2 text-[10px] font-bold uppercase tracking-wider text-[#5A7250]">
                    Recorded detection severity
                  </div>
                  <div className="flex flex-wrap gap-x-3 gap-y-1 text-[10px] font-semibold text-[#27421D]">
                    {[
                      ['#9f2d27', 'Critical'],
                      ['#e6634a', 'High'],
                      ['#f59e0b', 'Medium'],
                      ['#84a653', 'Low'],
                    ].map(([color, label]) => (
                      <span key={label} className="flex items-center gap-1">
                        <i
                          className="h-2.5 w-2.5 rounded-full"
                          style={{ backgroundColor: color }}
                        />
                        {label}
                      </span>
                    ))}
                  </div>
                  <div className="mt-1 text-[9px] text-[#71836a]">
                    Case locations and severity; district boundaries are geographic only.
                  </div>
                </div>
              </div>

              <aside className="space-y-5 border-t border-[#E2E9D4] p-5 lg:border-l lg:border-t-0">
                <div>
                  <h3 className="text-xs font-bold uppercase tracking-wider text-[#71836a]">
                    State metrics
                  </h3>
                  <div className="mt-3 grid grid-cols-2 gap-2">
                    {[
                      ['Total', expandedPoints.length],
                      ['Critical', expandedPoints.filter((point) => point.severity === 'CRITICAL').length],
                      ['High', expandedPoints.filter((point) => point.severity === 'HIGH').length],
                      ['Other', expandedPoints.filter((point) => point.severity === 'MEDIUM' || point.severity === 'LOW').length],
                    ].map(([label, value]) => (
                      <div
                        key={label}
                        className="rounded-xl border border-[#E2E9D4] bg-white/70 p-3"
                      >
                        <div className="text-[10px] font-semibold uppercase text-[#71836a]">
                          {label}
                        </div>
                        <div className="mt-1 text-xl font-black text-[#27421D]">
                          {value}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>

                <div>
                  <h3 className="text-xs font-bold uppercase tracking-wider text-[#71836a]">
                    Detected crops
                  </h3>
                  <div className="mt-2 flex flex-wrap gap-1.5">
                    {getTopValues(expandedPoints.map((point) => point.crop)).length ? (
                      getTopValues(expandedPoints.map((point) => point.crop)).map((crop) => (
                        <span
                          key={crop}
                          className="rounded-full bg-[#DCE9C7] px-2.5 py-1 text-[11px] font-bold text-[#27421D]"
                        >
                          {crop}
                        </span>
                      ))
                    ) : (
                      <span className="text-xs text-[#71836a]">No crop breakdown available</span>
                    )}
                  </div>
                </div>

                <div>
                  <h3 className="text-xs font-bold uppercase tracking-wider text-[#71836a]">
                    Common detections
                  </h3>
                  <div className="mt-2 space-y-2">
                    {getTopValues(expandedPoints.map((point) => point.condition)).length ? (
                      getTopValues(expandedPoints.map((point) => point.condition)).map((disease) => (
                        <div
                          key={disease}
                          className="flex items-center gap-2 text-xs font-medium text-[#27421D]"
                        >
                          <AlertTriangle className="h-3.5 w-3.5 shrink-0 text-[#C62828]" />
                          {disease}
                        </div>
                      ))
                    ) : (
                      <span className="text-xs text-[#71836a]">No disease breakdown available</span>
                    )}
                  </div>
                </div>

                <p className="border-t border-[#E2E9D4] pt-3 text-[10px] leading-relaxed text-[#71836a]">
                  Administrative boundaries are district-level reference geography (2011).
                  Heat intensity is based only on recorded detection locations and severity;
                  no district-level case totals are inferred.
                </p>
              </aside>
            </div>
          </section>
          <style jsx>{`
            .state-detail-panel {
              animation: state-detail-enter 180ms ease-out both;
            }
            @keyframes state-detail-enter {
              from {
                opacity: 0;
                transform: translateY(10px) scale(0.985);
              }
              to {
                opacity: 1;
                transform: translateY(0) scale(1);
              }
            }
          `}</style>
        </div>
      )}
    </div>
  );
}
