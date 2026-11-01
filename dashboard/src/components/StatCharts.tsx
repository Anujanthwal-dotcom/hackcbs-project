'use client';

import React from 'react';
import type { AnalyticsResponse, StateStat } from '../types';
import { AlertTriangle, TrendingUp, Bug, ShieldCheck, Sprout, Activity } from 'lucide-react';

interface StatChartsProps {
  analytics: AnalyticsResponse;
  selectedState: string;
  onSelectState: (stateName: string) => void;
}

export default function StatCharts({
  analytics,
  selectedState,
  onSelectState,
}: StatChartsProps) {
  const { stateStats, cropBreakdown, diseaseBreakdown, timelineTrends, summary } = analytics;

  // Maximum case count for scaling bars
  const maxStateCases = Math.max(...stateStats.map((s) => s.totalCases), 1);
  const maxTimelineCases = Math.max(...timelineTrends.map((t) => t.cases), 1);

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 w-full">
      {/* 1. State-wise Outbreak Breakdown */}
      <div className="bg-[#FAFCF5] p-6 rounded-3xl border border-[#E2E9D4] shadow-xs flex flex-col justify-between">
        <div>
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2.5">
              <div className="p-2 rounded-xl bg-[#DCE9C7] text-[#27421D]">
                <Activity className="w-4 h-4" />
              </div>
              <div>
                <h3 className="text-base font-bold text-[#27421D]">
                  State-wise Outbreak Intensity
                </h3>
                <p className="text-xs text-[#5A7250]">
                  Click a state to zoom in on the 2D heatmap
                </p>
              </div>
            </div>
            <span className="text-xs font-semibold px-2.5 py-1 rounded-full bg-[#E5ECCF] text-[#27421D]">
              {stateStats.filter((s) => s.totalCases > 0).length} Affected States
            </span>
          </div>

          <div className="space-y-3 mt-2">
            {stateStats.slice(0, 6).map((state) => {
              const isCurrent =
                selectedState !== 'ALL' &&
                state.name.toLowerCase().includes(selectedState.toLowerCase());
              const percent = (state.totalCases / maxStateCases) * 100;
              const critPercent = (state.criticalCases / maxStateCases) * 100;

              return (
                <div
                  key={state.id}
                  onClick={() => onSelectState(state.name)}
                  className={`p-3 rounded-2xl cursor-pointer transition-all border ${
                    isCurrent
                      ? 'bg-[#DCE9C7]/50 border-[#27421D] shadow-xs'
                      : 'hover:bg-[#F3F5EA] border-transparent'
                  }`}
                >
                  <div className="flex items-center justify-between text-xs mb-1.5">
                    <div className="flex items-center gap-2">
                      <span className="font-bold text-[#27421D]">{state.name}</span>
                      <span
                        className={`text-[10px] font-bold px-1.5 py-0.5 rounded-md ${
                          state.riskLevel === 'Critical'
                            ? 'bg-[#FEE2E2] text-[#991B1B]'
                            : state.riskLevel === 'Severe'
                            ? 'bg-[#FFEDD5] text-[#C2410C]'
                            : 'bg-[#FEF3C7] text-[#92400E]'
                        }`}
                      >
                        {state.riskLevel}
                      </span>
                    </div>
                    <div className="flex items-center gap-3 font-medium text-[#5A7250]">
                      <span>{state.totalCases} confirmed</span>
                      {state.criticalCases > 0 && (
                        <span className="text-[#C62828] font-bold">
                          {state.criticalCases} critical
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Dual Stacked Progress Bar */}
                  <div className="w-full h-2.5 bg-[#E2E9D4] rounded-full overflow-hidden flex">
                    <div
                      style={{ width: `${critPercent}%` }}
                      className="h-full bg-[#C62828] rounded-l-full transition-all duration-500"
                      title={`${state.criticalCases} Critical`}
                    />
                    <div
                      style={{ width: `${Math.max(0, percent - critPercent)}%` }}
                      className="h-full bg-[#EA580C] transition-all duration-500"
                      title={`${state.totalCases - state.criticalCases} High/Medium`}
                    />
                  </div>
                  <div className="flex justify-between items-center text-[10px] text-[#5A7250] mt-1.5">
                    <span>Key Crops: {state.topCrops.join(', ')}</span>
                    <span>Pest: {state.topDiseases.join(', ')}</span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* 2. Crop Vulnerability Distribution */}
      <div className="bg-[#FAFCF5] p-6 rounded-3xl border border-[#E2E9D4] shadow-xs flex flex-col justify-between">
        <div>
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2.5">
              <div className="p-2 rounded-xl bg-[#DCE9C7] text-[#27421D]">
                <Sprout className="w-4 h-4" />
              </div>
              <div>
                <h3 className="text-base font-bold text-[#27421D]">
                  Crop Vulnerability Share
                </h3>
                <p className="text-xs text-[#5A7250]">
                  Confirmed infestations categorized by agricultural crop
                </p>
              </div>
            </div>
          </div>

          <div className="space-y-3.5 mt-2">
            {cropBreakdown.slice(0, 5).map((item) => (
              <div key={item.crop} className="space-y-1">
                <div className="flex justify-between items-center text-xs">
                  <div className="flex items-center gap-2 font-bold text-[#27421D]">
                    <span>{item.crop}</span>
                    {item.critical > 0 && (
                      <span className="text-[10px] bg-[#FEE2E2] text-[#991B1B] font-bold px-1.5 py-0.5 rounded-md">
                        {item.critical} Critical
                      </span>
                    )}
                  </div>
                  <div className="flex items-center gap-2 text-[#5A7250] font-medium">
                    <span>{item.count} outbreaks</span>
                    <span className="font-bold text-[#27421D]">{item.percentage}%</span>
                  </div>
                </div>
                <div className="w-full h-3 bg-[#E2E9D4] rounded-full overflow-hidden p-0.5">
                  <div
                    style={{ width: `${item.percentage}%` }}
                    className="h-full bg-[#27421D] rounded-full transition-all duration-700"
                  />
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="mt-6 pt-4 border-t border-[#E2E9D4] flex items-center justify-between text-xs text-[#5A7250]">
          <span>Surveillance Accuracy Target: 95%+</span>
          <span className="font-semibold text-[#27421D]">
            Primary Vector: Cotton Pink Bollworm
          </span>
        </div>
      </div>

      {/* 3. Top Diagnosed Diseases & Pests */}
      <div className="bg-[#FAFCF5] p-6 rounded-3xl border border-[#E2E9D4] shadow-xs flex flex-col justify-between">
        <div>
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2.5">
              <div className="p-2 rounded-xl bg-[#DCE9C7] text-[#27421D]">
                <Bug className="w-4 h-4" />
              </div>
              <div>
                <h3 className="text-base font-bold text-[#27421D]">
                  Dominant Pest & Pathogen Vectors
                </h3>
                <p className="text-xs text-[#5A7250]">
                  Ranked by verified mobile ML & RAG diagnostics
                </p>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-2">
            {diseaseBreakdown.slice(0, 4).map((d) => (
              <div
                key={`${d.condition}-${d.crop}`}
                className="p-3.5 rounded-2xl bg-[#F3F5EA] border border-[#E2E9D4] flex flex-col justify-between gap-2"
              >
                <div className="flex items-start justify-between">
                  <span className="font-bold text-sm text-[#27421D]">
                    {d.condition}
                  </span>
                  <span
                    className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                      d.severity === 'CRITICAL'
                        ? 'bg-[#C62828] text-white'
                        : 'bg-[#EA580C] text-white'
                    }`}
                  >
                    {d.severity}
                  </span>
                </div>
                <div className="flex items-center justify-between text-xs text-[#5A7250] pt-2 border-t border-[#E2E9D4]/60">
                  <span>Target: {d.crop}</span>
                  <span className="font-bold text-[#27421D]">{d.count} Cases</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="mt-4 pt-3 border-t border-[#E2E9D4] text-xs text-[#5A7250] flex items-center gap-2">
          <ShieldCheck className="w-4 h-4 text-[#27421D]" />
          <span>Automated field spray advisories delivered to farmers</span>
        </div>
      </div>

      {/* 4. 14-Day Surveillance Progression Trend */}
      <div className="bg-[#FAFCF5] p-6 rounded-3xl border border-[#E2E9D4] shadow-xs flex flex-col justify-between">
        <div>
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2.5">
              <div className="p-2 rounded-xl bg-[#DCE9C7] text-[#27421D]">
                <TrendingUp className="w-4 h-4" />
              </div>
              <div>
                <h3 className="text-base font-bold text-[#27421D]">
                  14-Day Surveillance Progression
                </h3>
                <p className="text-xs text-[#5A7250]">
                  Daily confirmed field outbreaks and critical flare-ups
                </p>
              </div>
            </div>
            <span className="text-xs font-bold text-[#C62828] bg-[#FEE2E2] px-2.5 py-1 rounded-full">
              Hotspot Surge Active
            </span>
          </div>

          {/* SVG Area & Bar Trend Chart */}
          <div className="h-44 w-full flex items-end gap-1.5 pt-4 px-2">
            {timelineTrends.map((t, idx) => {
              const heightPercent = Math.max(12, (t.cases / maxTimelineCases) * 100);
              const critHeightPercent = t.cases > 0 ? (t.critical / t.cases) * heightPercent : 0;
              const dateLabel = t.date.slice(8); // '28', '29', etc.

              return (
                <div
                  key={t.date}
                  className="flex-1 flex flex-col items-center gap-1.5 h-full justify-end group cursor-pointer"
                  title={`${t.date}: ${t.cases} cases (${t.critical} critical)`}
                >
                  <span className="text-[10px] text-[#5A7250] font-semibold opacity-0 group-hover:opacity-100 transition-opacity">
                    {t.cases}
                  </span>
                  <div
                    style={{ height: `${heightPercent}%` }}
                    className="w-full rounded-t-lg bg-[#DCE9C7] relative overflow-hidden flex flex-col justify-end transition-all group-hover:bg-[#c8deb0]"
                  >
                    <div
                      style={{ height: `${critHeightPercent}%` }}
                      className="w-full bg-[#C62828] transition-all"
                    />
                  </div>
                  <span className="text-[10px] text-[#5A7250] font-medium">
                    {idx % 2 === 0 ? dateLabel : ''}
                  </span>
                </div>
              );
            })}
          </div>
        </div>

        <div className="flex items-center justify-between text-xs text-[#5A7250] pt-3 border-t border-[#E2E9D4] mt-2">
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-1.5">
              <span className="w-2.5 h-2.5 rounded-sm bg-[#C62828]" />
              <span>Critical Alerts</span>
            </div>
            <div className="flex items-center gap-1.5">
              <span className="w-2.5 h-2.5 rounded-sm bg-[#DCE9C7]" />
              <span>Confirmed Invasions</span>
            </div>
          </div>
          <span className="font-semibold text-[#27421D]">Weekly Trajectory: +18.4%</span>
        </div>
      </div>
    </div>
  );
}

