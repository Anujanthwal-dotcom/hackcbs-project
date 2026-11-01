'use client';

import React, { useState } from 'react';
import type { DetectionPoint } from '../types';
import { Search, Filter, MapPin, AlertCircle, CheckCircle2 } from 'lucide-react';

interface OutbreakDataTableProps {
  points: DetectionPoint[];
  selectedState: string;
  onSelectPoint?: (point: DetectionPoint) => void;
}

export default function OutbreakDataTable({
  points,
  selectedState,
  onSelectPoint,
}: OutbreakDataTableProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [severityFilter, setSeverityFilter] = useState('ALL');

  const filteredPoints = points.filter((p) => {
    const matchesSearch =
      p.crop.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.condition.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.state.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.district.toLowerCase().includes(searchQuery.toLowerCase());

    const matchesSeverity =
      severityFilter === 'ALL' || p.severity === severityFilter;

    return matchesSearch && matchesSeverity;
  });

  return (
    <div className="bg-[#FAFCF5] p-6 rounded-3xl border border-[#E2E9D4] shadow-xs w-full">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-5">
        <div>
          <h3 className="text-base font-bold text-[#27421D]">
            Confirmed Field Surveillance Feed
          </h3>
          <p className="text-xs text-[#5A7250]">
            Validated crop infestations recorded by mobile agent & verified by backend
          </p>
        </div>

        <div className="flex items-center gap-3">
          {/* Search Input */}
          <div className="relative">
            <Search className="w-4 h-4 absolute left-3 top-2.5 text-[#5A7250]" />
            <input
              type="text"
              placeholder="Search crop, disease, district..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9 pr-4 py-2 text-xs rounded-2xl bg-[#F3F5EA] border border-[#E2E9D4] text-[#27421D] placeholder:text-[#5A7250]/60 focus:outline-none focus:ring-1 focus:ring-[#27421D] w-56"
            />
          </div>

          {/* Severity Pill Selector */}
          <select
            value={severityFilter}
            onChange={(e) => setSeverityFilter(e.target.value)}
            className="px-3 py-2 text-xs rounded-2xl bg-[#F3F5EA] border border-[#E2E9D4] text-[#27421D] font-semibold focus:outline-none focus:ring-1 focus:ring-[#27421D]"
          >
            <option value="ALL">All Severities</option>
            <option value="CRITICAL">Critical Only</option>
            <option value="HIGH">High Severity</option>
            <option value="MEDIUM">Medium Severity</option>
            <option value="LOW">Low</option>
          </select>
        </div>
      </div>

      {/* Table container */}
      <div className="overflow-x-auto rounded-2xl border border-[#E2E9D4]">
        <table className="w-full text-left text-xs border-collapse">
          <thead>
            <tr className="bg-[#F3F5EA] text-[#5A7250] font-bold border-b border-[#E2E9D4]">
              <th className="py-3 px-4">Crop & Infestation</th>
              <th className="py-3 px-4">State & District</th>
              <th className="py-3 px-4">Coordinates</th>
              <th className="py-3 px-4">Validation Status</th>
              <th className="py-3 px-4">Confidence</th>
              <th className="py-3 px-4">Severity</th>
              <th className="py-3 px-4 text-right">Timestamp</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-[#E2E9D4]/70">
            {filteredPoints.length === 0 ? (
              <tr>
                <td colSpan={7} className="text-center py-8 text-[#5A7250]">
                  No confirmed outbreak records match the selected filters.
                </td>
              </tr>
            ) : (
              filteredPoints.slice(0, 10).map((p) => {
                const isCrit = p.severity === 'CRITICAL';
                return (
                  <tr
                    key={p.id}
                    onClick={() => onSelectPoint && onSelectPoint(p)}
                    className="hover:bg-[#F3F5EA]/80 transition-colors cursor-pointer group"
                  >
                    <td className="py-3 px-4 font-bold text-[#27421D]">
                      <div className="flex items-center gap-2">
                        <span className="w-2 h-2 rounded-full bg-[#C62828]" />
                        <span>{p.crop}</span>
                        <span className="font-normal text-[#5A7250]">• {p.condition}</span>
                      </div>
                    </td>
                    <td className="py-3 px-4 text-[#27421D]">
                      <div className="flex items-center gap-1.5">
                        <MapPin className="w-3.5 h-3.5 text-[#5A7250]" />
                        <span>
                          {p.district}, {p.state}
                        </span>
                      </div>
                    </td>
                    <td className="py-3 px-4 font-mono text-[11px] text-[#5A7250]">
                      {p.latitude.toFixed(4)}, {p.longitude.toFixed(4)}
                    </td>
                    <td className="py-3 px-4">
                      <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-[#27421D] bg-[#DCE9C7]/70 px-2 py-0.5 rounded-full">
                        <CheckCircle2 className="w-3 h-3 text-[#27421D]" />
                        Confirmed Target
                      </span>
                    </td>
                    <td className="py-3 px-4 font-bold text-[#27421D]">
                      {(p.confidence * 100).toFixed(1)}%
                    </td>
                    <td className="py-3 px-4">
                      <span
                        className={`text-[10px] font-extrabold px-2.5 py-0.5 rounded-full uppercase tracking-wider ${
                          isCrit
                            ? 'bg-[#FEE2E2] text-[#991B1B] border border-[#FCA5A5]'
                            : p.severity === 'HIGH'
                            ? 'bg-[#FFEDD5] text-[#C2410C] border border-[#FDBA74]'
                            : 'bg-[#FEF3C7] text-[#92400E]'
                        }`}
                      >
                        {p.severity}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-right text-[#5A7250]">
                      {new Date(p.createdAt).toLocaleDateString('en-IN', {
                        month: 'short',
                        day: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      <div className="mt-4 flex items-center justify-between text-xs text-[#5A7250]">
        <span>
          Showing {Math.min(10, filteredPoints.length)} of {filteredPoints.length} verified detections
        </span>
        <span className="font-semibold text-[#27421D]">
          Kisaan Bandhu ML • EfficientNetB0 V4 & Gemini Agro RAG
        </span>
      </div>
    </div>
  );
}

