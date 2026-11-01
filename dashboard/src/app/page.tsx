'use client';

import React, { useEffect, useState, useCallback } from 'react';
import dynamic from 'next/dynamic';
import {
  fetchAnalyticsData,
  fetchHeatmapData,
  triggerSeedDemo,
} from '../lib/api';
import type { AnalyticsResponse, DetectionPoint, HeatmapResponse } from '../types';
import StatCharts from '../components/StatCharts';
import OutbreakDataTable from '../components/OutbreakDataTable';
import {
  AlertTriangle,
  RefreshCw,
  Layers,
  MapPin,
  ShieldAlert,
  Sprout,
  Filter,
  CheckCircle2,
  Database,
  ExternalLink,
} from 'lucide-react';

// Dynamic import for Leaflet map component to prevent SSR hydration errors
const IndiaHeatmapMap = dynamic(
  () => import('../components/IndiaHeatmapMap'),
  {
    ssr: false,
    loading: () => (
      <div className="w-full h-[580px] rounded-3xl bg-[#FAFCF5] border border-[#E2E9D4] flex flex-col items-center justify-center gap-3 text-[#27421D]">
        <div className="w-10 h-10 border-4 border-[#27421D] border-t-transparent rounded-full animate-spin" />
        <span className="text-sm font-semibold">Initializing 2D India Surveillance Map...</span>
      </div>
    ),
  },
);

export default function DashboardPage() {
  const [heatmapData, setHeatmapData] = useState<HeatmapResponse | null>(null);
  const [analyticsData, setAnalyticsData] = useState<AnalyticsResponse | null>(null);
  const [isLiveBackend, setIsLiveBackend] = useState<boolean>(true);
  const [loading, setLoading] = useState<boolean>(true);
  const [seeding, setSeeding] = useState<boolean>(false);
  const [seedNotification, setSeedNotification] = useState<string | null>(null);

  // Filters state
  const [selectedState, setSelectedState] = useState<string>('ALL');
  const [selectedCrop, setSelectedCrop] = useState<string>('ALL');
  const [selectedSeverity, setSelectedSeverity] = useState<string>('ALL');
  const [selectedDays, setSelectedDays] = useState<number>(30);

  // Load data from backend
  const loadDashboardData = useCallback(async () => {
    setLoading(true);
    try {
      const [heatmapRes, analyticsRes] = await Promise.all([
        fetchHeatmapData({
          state: selectedState,
          crop: selectedCrop,
          severity: selectedSeverity,
          days: selectedDays,
        }),
        fetchAnalyticsData({
          state: selectedState,
          crop: selectedCrop,
        }),
      ]);

      setHeatmapData(heatmapRes.data);
      setAnalyticsData(analyticsRes.data);
      setIsLiveBackend(heatmapRes.isLive && analyticsRes.isLive);
    } catch (err) {
      console.error('Failed to load dashboard data:', err);
    } finally {
      setLoading(false);
    }
  }, [selectedState, selectedCrop, selectedSeverity, selectedDays]);

  useEffect(() => {
    loadDashboardData();
  }, [loadDashboardData]);

  // Handle seeding sample surveillance outbreaks in backend
  const handleSeedDemo = async () => {
    setSeeding(true);
    setSeedNotification(null);
    try {
      const res = await triggerSeedDemo();
      setSeedNotification(res.message);
      await loadDashboardData();
    } catch (err: any) {
      setSeedNotification(err.message || 'Seeding failed');
    } finally {
      setSeeding(false);
      setTimeout(() => setSeedNotification(null), 5000);
    }
  };

  const summary = heatmapData?.summary || analyticsData?.summary;
  const points = heatmapData?.points || [];
  const stateStats = analyticsData?.stateStats || [];

  return (
    <main className="min-h-screen bg-[#F3F5EA] text-[#27421D] p-4 md:p-8 space-y-6">
      {/* ── Header Bar ── */}
      <header className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-4 border-b border-[#E2E9D4]">
        <div className="flex items-center gap-3.5">
          <div className="w-12 h-12 rounded-2xl bg-[#27421D] flex items-center justify-center text-white text-2xl shadow-sm">
            🌾
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-xl md:text-2xl font-black text-[#27421D] tracking-tight">
                Kisaan Bandhu
              </h1>
              <span className="text-[11px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-[#DCE9C7] text-[#27421D]">
                Surveillance Grid
              </span>
            </div>
            <p className="text-xs text-[#5A7250] font-medium">
              National Agricultural Pest & Disease Outbreak Heatmap (India 2D)
            </p>
          </div>
        </div>

        {/* Action Controls & Backend Status */}
        <div className="flex flex-wrap items-center gap-2.5">
          {/* Backend Status Pill */}
          <div
            className={`flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-semibold border ${
              isLiveBackend
                ? 'bg-[#EBF3DF] text-[#27421D] border-[#CDE0B8]'
                : 'bg-[#FFFBEB] text-[#B45309] border-[#FDE68A]'
            }`}
          >
            <span
              className={`w-2 h-2 rounded-full ${
                isLiveBackend ? 'bg-[#2E7D32] animate-pulse' : 'bg-[#D97706]'
              }`}
            />
            <span>{isLiveBackend ? 'Backend Connected (:3000)' : 'Offline Cache Synced'}</span>
          </div>

          {/* Seed Surveillance Button */}
          <button
            onClick={handleSeedDemo}
            disabled={seeding}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-bold bg-[#DCE9C7] text-[#27421D] hover:bg-[#cde0b8] transition-all disabled:opacity-50"
            title="Seed national surveillance outbreak records in MongoDB"
          >
            <Database className="w-3.5 h-3.5" />
            <span>{seeding ? 'Seeding Data...' : 'Seed National Demo'}</span>
          </button>

          {/* Refresh Button */}
          <button
            onClick={loadDashboardData}
            disabled={loading}
            className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-full text-xs font-bold bg-[#27421D] text-white hover:bg-[#1E3416] transition-all disabled:opacity-50 shadow-xs"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            <span>Refresh</span>
          </button>
        </div>
      </header>

      {/* Seed Notification Toast */}
      {seedNotification && (
        <div className="p-3 bg-[#DCE9C7] border border-[#27421D]/30 text-[#27421D] rounded-2xl text-xs font-semibold flex items-center justify-between animate-fade-in">
          <span>🌾 {seedNotification}</span>
          <button
            onClick={() => setSeedNotification(null)}
            className="text-xs font-bold hover:underline"
          >
            Dismiss
          </button>
        </div>
      )}

      {/* ── Global Filter Bar ── */}
      <section className="bg-[#FAFCF5] p-4 rounded-3xl border border-[#E2E9D4] shadow-xs flex flex-wrap items-center justify-between gap-4">
        <div className="flex flex-wrap items-center gap-3">
          <div className="flex items-center gap-1.5 text-xs font-bold text-[#5A7250]">
            <Filter className="w-3.5 h-3.5 text-[#27421D]" />
            <span>Surveillance Filters:</span>
          </div>

          {/* State Zoom Selector */}
          <div className="flex items-center gap-1">
            <span className="text-[11px] font-semibold text-[#5A7250]">State:</span>
            <select
              value={selectedState}
              onChange={(e) => setSelectedState(e.target.value)}
              className="text-xs font-bold bg-[#F3F5EA] text-[#27421D] px-3 py-1.5 rounded-2xl border border-[#E2E9D4] focus:outline-none focus:ring-1 focus:ring-[#27421D]"
            >
              <option value="ALL">All India (National)</option>
              <option value="Maharashtra">Maharashtra (Vidarbha/Marathwada)</option>
              <option value="Punjab">Punjab (Bathinda/Malwa)</option>
              <option value="Gujarat">Gujarat (Saurashtra)</option>
              <option value="Karnataka">Karnataka (Belagavi/Kolar)</option>
              <option value="Madhya Pradesh">Madhya Pradesh (Malwa)</option>
              <option value="Uttar Pradesh">Uttar Pradesh (Doab/Terai)</option>
              <option value="Andhra Pradesh">Andhra Pradesh (Guntur)</option>
              <option value="Telangana">Telangana (Warangal)</option>
              <option value="Rajasthan">Rajasthan (Sri Ganganagar)</option>
              <option value="West Bengal">West Bengal (Burdwan)</option>
              <option value="Haryana & Delhi">Haryana & Delhi NCR</option>
            </select>
          </div>

          {/* Crop Filter */}
          <div className="flex items-center gap-1">
            <span className="text-[11px] font-semibold text-[#5A7250]">Crop:</span>
            <select
              value={selectedCrop}
              onChange={(e) => setSelectedCrop(e.target.value)}
              className="text-xs font-bold bg-[#F3F5EA] text-[#27421D] px-3 py-1.5 rounded-2xl border border-[#E2E9D4] focus:outline-none focus:ring-1 focus:ring-[#27421D]"
            >
              <option value="ALL">All Crops</option>
              <option value="Cotton">Cotton (Kapas)</option>
              <option value="Soybean">Soybean</option>
            </select>
          </div>

          {/* Severity Filter */}
          <div className="flex items-center gap-1">
            <span className="text-[11px] font-semibold text-[#5A7250]">Severity:</span>
            <select
              value={selectedSeverity}
              onChange={(e) => setSelectedSeverity(e.target.value)}
              className="text-xs font-bold bg-[#F3F5EA] text-[#27421D] px-3 py-1.5 rounded-2xl border border-[#E2E9D4] focus:outline-none focus:ring-1 focus:ring-[#27421D]"
            >
              <option value="ALL">All Severities</option>
              <option value="CRITICAL">🔴 Critical Outbreaks</option>
              <option value="HIGH">🟠 High Severity</option>
              <option value="MEDIUM">🟡 Medium Severity</option>
              <option value="LOW">🟢 Low Severity</option>
            </select>
          </div>
        </div>

        {/* Clear Filters Button */}
        {(selectedState !== 'ALL' || selectedCrop !== 'ALL' || selectedSeverity !== 'ALL') && (
          <button
            onClick={() => {
              setSelectedState('ALL');
              setSelectedCrop('ALL');
              setSelectedSeverity('ALL');
            }}
            className="text-xs font-bold text-[#C62828] hover:underline"
          >
            Reset Filters
          </button>
        )}
      </section>

      {/* ── Top Metric Cards (Mobile App Theme) ── */}
      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {/* Total Confirmed */}
        <div className="p-5 rounded-3xl bg-[#FAFCF5] border border-[#E2E9D4] shadow-xs flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-[#5A7250] uppercase tracking-wider">
              Confirmed Outbreaks
            </span>
            <span className="p-1.5 rounded-xl bg-[#DCE9C7] text-[#27421D]">
              <Sprout className="w-4 h-4" />
            </span>
          </div>
          <div className="mt-2">
            <span className="text-3xl font-black text-[#27421D]">
              {summary?.totalConfirmed ?? 0}
            </span>
            <span className="text-xs text-[#5A7250] ml-2">Verified targets</span>
          </div>
        </div>

        {/* Critical Emergency Hotspots */}
        <div className="p-5 rounded-3xl bg-[#FAFCF5] border border-[#E2E9D4] shadow-xs flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-[#C62828] uppercase tracking-wider">
              Critical Hotspots
            </span>
            <span className="p-1.5 rounded-xl bg-[#FEE2E2] text-[#991B1B]">
              <ShieldAlert className="w-4 h-4" />
            </span>
          </div>
          <div className="mt-2">
            <span className="text-3xl font-black text-[#C62828]">
              {summary?.criticalCount ?? 0}
            </span>
            <span className="text-xs text-[#C62828] font-semibold ml-2">
              Immediate quarantine
            </span>
          </div>
        </div>

        {/* Active Hotspot States */}
        <div className="p-5 rounded-3xl bg-[#FAFCF5] border border-[#E2E9D4] shadow-xs flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-[#5A7250] uppercase tracking-wider">
              Active State Clusters
            </span>
            <span className="p-1.5 rounded-xl bg-[#DCE9C7] text-[#27421D]">
              <MapPin className="w-4 h-4" />
            </span>
          </div>
          <div className="mt-2">
            <span className="text-3xl font-black text-[#27421D]">
              {summary?.activeHotspotStates ?? 0}
            </span>
            <span className="text-xs text-[#5A7250] ml-2">
              {selectedState !== 'ALL' ? selectedState : 'National coverage'}
            </span>
          </div>
        </div>

        {/* Primary Vector */}
        <div className="p-5 rounded-3xl bg-[#FAFCF5] border border-[#E2E9D4] shadow-xs flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-[#5A7250] uppercase tracking-wider">
              Top Threat Vector
            </span>
            <span className="p-1.5 rounded-xl bg-[#DCE9C7] text-[#27421D]">
              <AlertTriangle className="w-4 h-4" />
            </span>
          </div>
          <div className="mt-2">
            <div className="text-base font-black text-[#27421D] truncate">
              {summary?.topDisease || 'Pink Bollworm'}
            </div>
            <span className="text-xs text-[#5A7250]">
              Target Crop: {summary?.topAffectedCrop || 'Cotton'}
            </span>
          </div>
        </div>
      </section>

      {/* ── Main Section: 2D Heatmap for India ── */}
      <section className="space-y-3">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
          <div>
            <h2 className="text-lg font-bold text-[#27421D] flex items-center gap-2">
              <span>Confirmed Outbreak Hotspots Map</span>
              {selectedState !== 'ALL' && (
                <span className="text-xs bg-[#DCE9C7] text-[#27421D] font-bold px-2 py-0.5 rounded-full">
                  Region: {selectedState}
                </span>
              )}
            </h2>
            <p className="text-xs text-[#5A7250]">
              Real 2D map showing confirmed pest and disease hot points in red. Use state zoom options to inspect regional outbreak clusters.
            </p>
          </div>

          <div className="text-xs text-[#5A7250] font-medium flex items-center gap-2">
            <span>🔴 Darker red = High infestation density</span>
          </div>
        </div>

        {/* The 2D Map Container */}
        <IndiaHeatmapMap
          points={points}
          selectedState={selectedState}
          onSelectState={(st) => setSelectedState(st)}
          stateStats={stateStats}
        />
      </section>

      {/* ── Statistics & Diagnostic Charts ── */}
      {analyticsData && (
        <section className="space-y-3 pt-2">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-lg font-bold text-[#27421D]">
                Outbreak Analytics & Agronomic Insights
              </h2>
              <p className="text-xs text-[#5A7250]">
                Correlated with mobile camera model inferences and field farmer telemetry
              </p>
            </div>
          </div>

          <StatCharts
            analytics={analyticsData}
            selectedState={selectedState}
            onSelectState={(st) => setSelectedState(st)}
          />
        </section>
      )}

      {/* ── Outbreak Records Surveillance Feed ── */}
      <section className="pt-2">
        <OutbreakDataTable
          points={points}
          selectedState={selectedState}
          onSelectPoint={(p) => {
            setSelectedState(p.state);
          }}
        />
      </section>

      {/* ── Footer ── */}
      <footer className="pt-8 pb-4 text-center text-xs text-[#5A7250] border-t border-[#E2E9D4] flex flex-col sm:flex-row items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <span className="w-2 h-2 rounded-full bg-[#27421D]" />
          <span>Kisaan Bandhu Agricultural Decision Support System • SIH 2026</span>
        </div>
        <div>
          NestJS 11 • Prisma MongoDB • Next.js 16 (App Router) • Flutter Multi-Platform
        </div>
      </footer>
    </main>
  );
}
