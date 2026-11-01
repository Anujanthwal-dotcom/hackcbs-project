import type { AnalyticsResponse, DetectionPoint, HeatmapResponse, StateStat } from '../types';

const BACKEND_BASE_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL || 'http://localhost:3000';

export async function fetchHeatmapData(params?: {
  crop?: string;
  severity?: string;
  state?: string;
  days?: number;
}): Promise<{ data: HeatmapResponse; isLive: boolean }> {
  const query = new URLSearchParams();
  if (params?.crop && params.crop !== 'ALL') query.set('crop', params.crop);
  if (params?.severity && params.severity !== 'ALL') query.set('severity', params.severity);
  if (params?.state && params.state !== 'ALL') query.set('state', params.state);
  if (params?.days) query.set('days', params.days.toString());

  const url = `${BACKEND_BASE_URL}/detections/heatmap?${query.toString()}`;

  try {
    const res = await fetch(url, {
      method: 'GET',
      headers: { 'Content-Type': 'application/json' },
      cache: 'no-store',
    });

    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    }

    const data: HeatmapResponse = await res.json();
    return { data, isLive: true };
  } catch (error) {
    console.warn(`[API] Failed to fetch heatmap from ${url}. Returning fallback.`, error);
    return { data: getFallbackHeatmapData(params), isLive: false };
  }
}

export async function fetchAnalyticsData(params?: {
  state?: string;
  crop?: string;
}): Promise<{ data: AnalyticsResponse; isLive: boolean }> {
  const query = new URLSearchParams();
  if (params?.state && params.state !== 'ALL') query.set('state', params.state);
  if (params?.crop && params.crop !== 'ALL') query.set('crop', params.crop);

  const url = `${BACKEND_BASE_URL}/detections/analytics?${query.toString()}`;

  try {
    const res = await fetch(url, {
      method: 'GET',
      headers: { 'Content-Type': 'application/json' },
      cache: 'no-store',
    });

    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    }

    const data: AnalyticsResponse = await res.json();
    return { data, isLive: true };
  } catch (error) {
    console.warn(`[API] Failed to fetch analytics from ${url}. Returning fallback.`, error);
    return { data: getFallbackAnalyticsData(params), isLive: false };
  }
}

export async function triggerSeedDemo(): Promise<{ success: boolean; message: string }> {
  try {
    const res = await fetch(`${BACKEND_BASE_URL}/detections/seed-demo`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const body = await res.json();
    return { success: true, message: body.message || 'Seeded successfully' };
  } catch (err: any) {
    return { success: false, message: err.message || 'Failed to connect to backend' };
  }
}

// ─────────────────────────────────────────────────────────────
// Fallback datasets ensuring 100% operational UI even if backend offline
// ─────────────────────────────────────────────────────────────

function getFallbackHeatmapData(params?: {
  crop?: string;
  severity?: string;
  state?: string;
  days?: number;
}): HeatmapResponse {
  const fallbackPoints: DetectionPoint[] = [
    // Maharashtra
    { id: 'fb-1', latitude: 20.3888, longitude: 78.1204, crop: 'Cotton', condition: 'Pink Bollworm', predictedClass: 'Cotton_Pink_Bollworm', confidence: 0.98, severity: 'CRITICAL', isCritical: true, status: 'validTarget', state: 'Maharashtra', stateCode: 'MH', district: 'Yavatmal', weight: 0.98, createdAt: new Date().toISOString() },
    { id: 'fb-2', latitude: 20.7002, longitude: 77.0082, crop: 'Soybean', condition: 'Caterpillar', predictedClass: 'Soybean_Caterpillar', confidence: 0.94, severity: 'HIGH', isCritical: false, status: 'validTarget', state: 'Maharashtra', stateCode: 'MH', district: 'Akola', weight: 0.71, createdAt: new Date().toISOString() },
    { id: 'fb-3', latitude: 21.1458, longitude: 79.0882, crop: 'Cotton', condition: 'Pink Bollworm', predictedClass: 'Cotton_Pink_Bollworm', confidence: 0.96, severity: 'CRITICAL', isCritical: true, status: 'validTarget', state: 'Maharashtra', stateCode: 'MH', district: 'Nagpur', weight: 0.96, createdAt: new Date().toISOString() },
    { id: 'fb-4', latitude: 19.8762, longitude: 75.3433, crop: 'Cotton', condition: 'Bacterial Blight', predictedClass: 'Cotton_Bacterial_Blight', confidence: 0.92, severity: 'HIGH', isCritical: false, status: 'validTarget', state: 'Maharashtra', stateCode: 'MH', district: 'Aurangabad', weight: 0.69, createdAt: new Date().toISOString() },

    // Punjab
    { id: 'fb-5', latitude: 30.2110, longitude: 74.9455, crop: 'Cotton', condition: 'Pink Bollworm', predictedClass: 'Cotton_Pink_Bollworm', confidence: 0.99, severity: 'CRITICAL', isCritical: true, status: 'validTarget', state: 'Punjab', stateCode: 'PB', district: 'Bathinda', weight: 0.99, createdAt: new Date().toISOString() },
    { id: 'fb-6', latitude: 29.9880, longitude: 75.3880, crop: 'Cotton', condition: 'Pink Bollworm', predictedClass: 'Cotton_Pink_Bollworm', confidence: 0.95, severity: 'CRITICAL', isCritical: true, status: 'validTarget', state: 'Punjab', stateCode: 'PB', district: 'Mansa', weight: 0.95, createdAt: new Date().toISOString() },

    // Gujarat
    { id: 'fb-8', latitude: 22.3039, longitude: 70.8022, crop: 'Cotton', condition: 'Pink Bollworm', predictedClass: 'Cotton_Pink_Bollworm', confidence: 0.97, severity: 'CRITICAL', isCritical: true, status: 'validTarget', state: 'Gujarat', stateCode: 'GJ', district: 'Rajkot', weight: 0.97, createdAt: new Date().toISOString() },

    // Karnataka
    { id: 'fb-11', latitude: 16.2120, longitude: 77.3439, crop: 'Cotton', condition: 'Pink Bollworm', predictedClass: 'Cotton_Pink_Bollworm', confidence: 0.95, severity: 'CRITICAL', isCritical: true, status: 'validTarget', state: 'Karnataka', stateCode: 'KA', district: 'Raichur', weight: 0.95, createdAt: new Date().toISOString() },

    // Madhya Pradesh
    { id: 'fb-12', latitude: 22.7196, longitude: 75.8577, crop: 'Soybean', condition: 'Caterpillar', predictedClass: 'Soybean_Caterpillar', confidence: 0.96, severity: 'HIGH', isCritical: false, status: 'validTarget', state: 'Madhya Pradesh', stateCode: 'MP', district: 'Indore', weight: 0.72, createdAt: new Date().toISOString() },
    { id: 'fb-13', latitude: 22.9676, longitude: 76.0534, crop: 'Soybean', condition: 'Yellow Mosaic', predictedClass: 'Soybean_Yellow_Mosaic', confidence: 0.93, severity: 'HIGH', isCritical: false, status: 'validTarget', state: 'Madhya Pradesh', stateCode: 'MP', district: 'Dewas', weight: 0.7, createdAt: new Date().toISOString() },

    // Telangana
    { id: 'fb-17', latitude: 17.9689, longitude: 79.5941, crop: 'Cotton', condition: 'Pink Bollworm', predictedClass: 'Cotton_Pink_Bollworm', confidence: 0.96, severity: 'CRITICAL', isCritical: true, status: 'validTarget', state: 'Telangana', stateCode: 'TS', district: 'Warangal', weight: 0.96, createdAt: new Date().toISOString() },

    // Delhi NCR
    { id: 'fb-18', latitude: 28.7328, longitude: 77.1185, crop: 'Cotton', condition: 'Pink Bollworm', predictedClass: 'Cotton_Pink_Bollworm', confidence: 0.96, severity: 'CRITICAL', isCritical: true, status: 'validTarget', state: 'Haryana & Delhi', stateCode: 'HR', district: 'Delhi NCR', weight: 0.96, createdAt: new Date().toISOString() },
  ];

  let filtered = fallbackPoints;
  if (params?.crop && params.crop !== 'ALL') {
    filtered = filtered.filter((p) => p.crop.toLowerCase() === params.crop!.toLowerCase());
  }
  if (params?.severity && params.severity !== 'ALL') {
    filtered = filtered.filter((p) => p.severity === params.severity);
  }
  if (params?.state && params.state !== 'ALL') {
    filtered = filtered.filter(
      (p) =>
        p.state.toLowerCase() === params.state!.toLowerCase() ||
        p.stateCode.toLowerCase() === params.state!.toLowerCase(),
    );
  }

  const cropCounts = filtered.reduce<Record<string, number>>((counts, point) => {
    counts[point.crop] = (counts[point.crop] || 0) + 1;
    return counts;
  }, {});
  const diseaseCounts = filtered.reduce<Record<string, number>>((counts, point) => {
    counts[point.condition] = (counts[point.condition] || 0) + 1;
    return counts;
  }, {});

  return {
    summary: {
      totalConfirmed: filtered.length,
      criticalCount: filtered.filter((p) => p.severity === 'CRITICAL').length,
      highCount: filtered.filter((p) => p.severity === 'HIGH').length,
      mediumCount: filtered.filter((p) => p.severity === 'MEDIUM').length,
      lowCount: filtered.filter((p) => p.severity === 'LOW').length,
      activeHotspotStates: new Set(filtered.map((point) => point.stateCode)).size,
      topAffectedCrop: Object.entries(cropCounts).sort((a, b) => b[1] - a[1])[0]?.[0] || 'Cotton',
      topDisease: Object.entries(diseaseCounts).sort((a, b) => b[1] - a[1])[0]?.[0] || 'Pink Bollworm',
    },
    points: filtered,
    activeFilters: {
      crop: params?.crop || 'ALL',
      severity: params?.severity || 'ALL',
      state: params?.state || 'ALL',
      days: params?.days || 30,
    },
  };
}

function getFallbackAnalyticsData(params?: {
  state?: string;
  crop?: string;
}): AnalyticsResponse {
  const heatmap = getFallbackHeatmapData(params);
  const points = heatmap.points;
  const stateMetadata: StateStat[] = [
    { id: 'MH', name: 'Maharashtra', code: 'MH', center: { lat: 19.7515, lng: 75.7139 }, zoom: 6.8, bounds: [[15.6, 72.6], [22.1, 80.9]], totalCases: 0, criticalCases: 0, riskLevel: 'Low', topCrops: [], topDiseases: [] },
    { id: 'PB', name: 'Punjab', code: 'PB', center: { lat: 31.1471, lng: 75.3412 }, zoom: 7.5, bounds: [[29.5, 73.8], [32.5, 76.9]], totalCases: 0, criticalCases: 0, riskLevel: 'Low', topCrops: [], topDiseases: [] },
    { id: 'GJ', name: 'Gujarat', code: 'GJ', center: { lat: 22.2587, lng: 71.1924 }, zoom: 6.8, bounds: [[20.1, 68.1], [24.7, 74.5]], totalCases: 0, criticalCases: 0, riskLevel: 'Low', topCrops: [], topDiseases: [] },
    { id: 'KA', name: 'Karnataka', code: 'KA', center: { lat: 15.3173, lng: 75.7139 }, zoom: 6.7, bounds: [[11.5, 74.0], [18.5, 78.6]], totalCases: 0, criticalCases: 0, riskLevel: 'Low', topCrops: [], topDiseases: [] },
    { id: 'MP', name: 'Madhya Pradesh', code: 'MP', center: { lat: 22.9734, lng: 78.6569 }, zoom: 6.4, bounds: [[21.0, 74.0], [26.9, 82.8]], totalCases: 0, criticalCases: 0, riskLevel: 'Low', topCrops: [], topDiseases: [] },
    { id: 'TS', name: 'Telangana', code: 'TS', center: { lat: 18.1124, lng: 79.0193 }, zoom: 7.0, bounds: [[15.8, 77.2], [19.9, 81.3]], totalCases: 0, criticalCases: 0, riskLevel: 'Low', topCrops: [], topDiseases: [] },
    { id: 'HR', name: 'Haryana & Delhi', code: 'HR', center: { lat: 29.0588, lng: 76.0856 }, zoom: 7.5, bounds: [[27.6, 74.4], [30.9, 77.6]], totalCases: 0, criticalCases: 0, riskLevel: 'Low', topCrops: [], topDiseases: [] },
  ];

  const stateStats = stateMetadata.map((state) => {
    const statePoints = points.filter((point) => point.stateCode === state.code);
    const criticalCases = statePoints.filter((point) => point.severity === 'CRITICAL').length;
    const totalCases = statePoints.length;
    let riskLevel: StateStat['riskLevel'] = 'Low';
    if (criticalCases >= 5 || totalCases >= 12) riskLevel = 'Critical';
    else if (criticalCases >= 2 || totalCases >= 6) riskLevel = 'Severe';
    else if (totalCases >= 2) riskLevel = 'Elevated';
    else if (totalCases > 0) riskLevel = 'Moderate';

    return {
      ...state,
      totalCases,
      criticalCases,
      riskLevel,
      topCrops: [...new Set(statePoints.map((point) => point.crop))],
      topDiseases: [...new Set(statePoints.map((point) => point.condition))],
    };
  }).sort((a, b) => b.totalCases - a.totalCases);

  const cropCounts = new Map<string, { count: number; critical: number }>();
  const diseaseCounts = new Map<string, { crop: string; count: number; severity: string }>();
  for (const point of points) {
    const crop = cropCounts.get(point.crop) || { count: 0, critical: 0 };
    crop.count++;
    if (point.severity === 'CRITICAL') crop.critical++;
    cropCounts.set(point.crop, crop);

    const key = `${point.condition}__${point.crop}`;
    const disease = diseaseCounts.get(key) || {
      crop: point.crop,
      count: 0,
      severity: point.severity,
    };
    disease.count++;
    if (point.severity === 'CRITICAL') disease.severity = 'CRITICAL';
    diseaseCounts.set(key, disease);
  }

  const totalCount = points.length || 1;
  const cropBreakdown = [...cropCounts.entries()]
    .map(([crop, data]) => ({
      crop,
      count: data.count,
      critical: data.critical,
      percentage: Number(((data.count / totalCount) * 100).toFixed(1)),
    }))
    .sort((a, b) => b.count - a.count);
  const diseaseBreakdown = [...diseaseCounts.entries()]
    .map(([key, data]) => ({
      condition: key.split('__')[0],
      crop: data.crop,
      count: data.count,
      severity: data.severity,
      percentage: Number(((data.count / totalCount) * 100).toFixed(1)),
    }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 8);

  const timelineMap = new Map<string, { date: string; cases: number; critical: number }>();
  for (let i = 13; i >= 0; i--) {
    const date = new Date();
    date.setDate(date.getDate() - i);
    const dateString = date.toISOString().slice(0, 10);
    timelineMap.set(dateString, { date: dateString, cases: 0, critical: 0 });
  }
  for (const point of points) {
    const date = new Date(point.createdAt).toISOString().slice(0, 10);
    const trend = timelineMap.get(date);
    if (trend) {
      trend.cases++;
      if (point.severity === 'CRITICAL') trend.critical++;
    }
  }

  return {
    summary: heatmap.summary,
    stateStats,
    cropBreakdown,
    diseaseBreakdown,
    timelineTrends: [...timelineMap.values()],
  };
}
