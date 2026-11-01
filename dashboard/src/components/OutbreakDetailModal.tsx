'use client';

import React, { useState } from 'react';
import type { DetectionPoint } from '../types';
import {
  X,
  MapPin,
  Calendar,
  ShieldAlert,
  Sprout,
  Copy,
  Check,
  ExternalLink,
  Sparkles,
  Info,
} from 'lucide-react';

interface OutbreakDetailModalProps {
  point: DetectionPoint | null;
  onClose: () => void;
  onFocusMap?: (point: DetectionPoint) => void;
}

export default function OutbreakDetailModal({
  point,
  onClose,
  onFocusMap,
}: OutbreakDetailModalProps) {
  const [copied, setCopied] = useState(false);

  if (!point) return null;

  const isCritical = point.severity === 'CRITICAL';
  const isHigh = point.severity === 'HIGH';

  const copyCoordinates = () => {
    navigator.clipboard.writeText(`${point.latitude}, ${point.longitude}`);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const formattedDate = point.createdAt
    ? new Date(point.createdAt).toLocaleString('en-IN', {
        dateStyle: 'medium',
        timeStyle: 'short',
      })
    : 'Recently detected';

  return (
    <div className="fixed inset-0 z-[1000] flex items-center justify-center p-4 bg-black/40 backdrop-blur-xs animate-fade-in">
      <div className="bg-[#FAFCF5] rounded-3xl border border-[#E2E9D4] shadow-2xl max-w-lg w-full overflow-hidden text-[#27421D]">
        {/* Header */}
        <div className="p-5 border-b border-[#E2E9D4] flex items-center justify-between bg-[#F3F5EA]">
          <div className="flex items-center gap-2.5">
            <span
              className={`w-3 h-3 rounded-full ${
                isCritical ? 'bg-[#C62828] animate-ping' : 'bg-[#EA580C]'
              }`}
            />
            <span className="text-xs font-black uppercase tracking-wider text-[#5A7250]">
              Field Surveillance Outbreak Telemetry
            </span>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-full hover:bg-[#E2E9D4] text-[#5A7250] hover:text-[#27421D] transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Body Content */}
        <div className="p-6 space-y-5 max-h-[75vh] overflow-y-auto">
          {/* Outbreak Hero */}
          <div className="flex items-start justify-between gap-4">
            <div>
              <div className="flex items-center gap-2 mb-1">
                <span
                  className={`text-[11px] font-black uppercase px-2.5 py-0.5 rounded-full ${
                    isCritical
                      ? 'bg-[#FEE2E2] text-[#991B1B] border border-[#F87171]/40'
                      : isHigh
                      ? 'bg-[#FFEDD5] text-[#C2410C] border border-[#FB923C]/40'
                      : 'bg-[#FEF3C7] text-[#92400E] border border-[#FBBF24]/40'
                  }`}
                >
                  {point.severity} Alert
                </span>
                <span className="text-xs text-[#5A7250] font-semibold">
                  Record ID: #{point.id.slice(-6)}
                </span>
              </div>
              <h2 className="text-xl font-black text-[#27421D]">
                {point.crop} — {point.condition}
              </h2>
              <p className="text-xs text-[#5A7250] font-medium">
                Model Classification: <code className="bg-[#E2E9D4]/60 px-1.5 py-0.5 rounded">{point.predictedClass}</code>
              </p>
            </div>

            <div className="p-3 bg-[#DCE9C7]/50 rounded-2xl border border-[#DCE9C7] flex flex-col items-center min-w-[90px]">
              <span className="text-[10px] uppercase font-bold text-[#5A7250]">AI Confidence</span>
              <span className="text-xl font-black text-[#27421D]">
                {(point.confidence * 100).toFixed(1)}%
              </span>
            </div>
          </div>

          {/* Location & Coordinates Grid */}
          <div className="grid grid-cols-2 gap-3 p-4 bg-[#F3F5EA] rounded-2xl border border-[#E2E9D4]">
            <div className="flex items-start gap-2">
              <MapPin className="w-4 h-4 text-[#27421D] mt-0.5 shrink-0" />
              <div>
                <span className="text-[11px] text-[#5A7250] block font-semibold">Region & District</span>
                <span className="text-xs font-bold text-[#27421D]">
                  {point.district}, {point.state}
                </span>
              </div>
            </div>

            <div className="flex items-start gap-2">
              <Calendar className="w-4 h-4 text-[#27421D] mt-0.5 shrink-0" />
              <div>
                <span className="text-[11px] text-[#5A7250] block font-semibold">Timestamp</span>
                <span className="text-xs font-bold text-[#27421D]">{formattedDate}</span>
              </div>
            </div>

            <div className="col-span-2 pt-2 border-t border-[#E2E9D4]/60 flex items-center justify-between">
              <div className="text-xs font-mono text-[#27421D]">
                GPS: <strong>{point.latitude.toFixed(5)}, {point.longitude.toFixed(5)}</strong>
              </div>
              <button
                onClick={copyCoordinates}
                className="flex items-center gap-1 text-[11px] font-bold text-[#27421D] hover:bg-[#DCE9C7] px-2 py-1 rounded-lg transition-colors"
              >
                {copied ? <Check className="w-3.5 h-3.5 text-[#2E7D32]" /> : <Copy className="w-3.5 h-3.5" />}
                <span>{copied ? 'Copied' : 'Copy GPS'}</span>
              </button>
            </div>
          </div>

          {/* AI Recommendation / Field Advisory */}
          <div className="p-4 bg-[#EBF3DF] rounded-2xl border border-[#CDE0B8] space-y-2">
            <div className="flex items-center gap-2 text-xs font-bold text-[#27421D]">
              <Sparkles className="w-4 h-4 text-[#2E7D32]" />
              <span>Recommended Agronomic Action & Advisory</span>
            </div>
            <p className="text-xs text-[#27421D] leading-relaxed">
              {point.latestRecommendation ||
                `Confirmed target of ${point.condition} in ${point.crop}. Initiate immediate containment protocol, inspect adjacent rows within 200m, and alert regional agriculture extension officers.`}
            </p>
          </div>

          {/* Outbreak Status Indicators */}
          <div className="flex items-center justify-between text-xs font-medium text-[#5A7250] px-1">
            <div className="flex items-center gap-1.5">
              <Info className="w-3.5 h-3.5 text-[#27421D]" />
              <span>Telemetry Status: <strong className="text-[#27421D]">{point.status}</strong></span>
            </div>
            <span>Surveillance Weight: <strong>{point.weight}</strong></span>
          </div>
        </div>

        {/* Footer Actions */}
        <div className="p-4 bg-[#F3F5EA] border-t border-[#E2E9D4] flex items-center justify-end gap-2.5">
          <button
            onClick={onClose}
            className="px-4 py-2 text-xs font-bold text-[#5A7250] hover:text-[#27421D] transition-colors"
          >
            Close
          </button>
          {onFocusMap && (
            <button
              onClick={() => {
                onFocusMap(point);
                onClose();
              }}
              className="flex items-center gap-1.5 px-4 py-2 text-xs font-bold bg-[#27421D] text-white rounded-2xl hover:bg-[#1E3416] transition-all shadow-xs"
            >
              <MapPin className="w-3.5 h-3.5" />
              <span>Focus on 2D Map</span>
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

