export interface DetectionPoint {
  id: string;
  latitude: number;
  longitude: number;
  crop: string;
  condition: string;
  predictedClass: string;
  confidence: number;
  severity: 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW';
  isCritical: boolean;
  status: string;
  state: string;
  stateCode: string;
  district: string;
  weight: number;
  createdAt: string;
  latestSeverity?: string | null;
  latestRecommendation?: string | null;
  reviewCount?: number;
}

export interface HeatmapSummary {
  totalConfirmed: number;
  criticalCount: number;
  highCount: number;
  mediumCount: number;
  lowCount: number;
  activeHotspotStates: number;
  topAffectedCrop: string;
  topDisease: string;
}

export interface StateStat {
  id: string;
  name: string;
  code: string;
  center: { lat: number; lng: number };
  zoom: number;
  bounds: [[number, number], [number, number]];
  totalCases: number;
  criticalCases: number;
  riskLevel: 'Critical' | 'Severe' | 'Elevated' | 'Moderate' | 'Low';
  topCrops: string[];
  topDiseases: string[];
}

export interface CropBreakdown {
  crop: string;
  count: number;
  critical: number;
  percentage: number;
}

export interface DiseaseBreakdown {
  condition: string;
  crop: string;
  count: number;
  severity: string;
  percentage: number;
}

export interface TimelineTrend {
  date: string;
  cases: number;
  critical: number;
}

export interface HeatmapResponse {
  summary: HeatmapSummary;
  points: DetectionPoint[];
  activeFilters: {
    crop: string;
    severity: string;
    state: string;
    days: number;
  };
}

export interface AnalyticsResponse {
  summary: HeatmapSummary;
  stateStats: StateStat[];
  cropBreakdown: CropBreakdown[];
  diseaseBreakdown: DiseaseBreakdown[];
  timelineTrends: TimelineTrend[];
}

