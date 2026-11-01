import {
  IsBoolean,
  IsEnum,
  IsIn,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
} from 'class-validator';
import { SUPPORTED_CROPS } from '../crops.constants.js';

export enum SeverityLevel {
  LOW = 'LOW',
  MEDIUM = 'MEDIUM',
  HIGH = 'HIGH',
  CRITICAL = 'CRITICAL',
}

export class CreateDetectionDto {
  @IsString()
  @IsIn(SUPPORTED_CROPS)
  @IsNotEmpty()
  crop: string;

  @IsString()
  @IsNotEmpty()
  predictedClass: string;

  @IsString()
  @IsNotEmpty()
  condition: string;

  @IsNumber()
  @IsNotEmpty()
  confidence: number;

  @IsEnum(SeverityLevel)
  @IsOptional()
  severity?: SeverityLevel = SeverityLevel.CRITICAL;

  @IsBoolean()
  @IsOptional()
  isCritical?: boolean = true;

  @IsNumber()
  @IsOptional()
  margin?: number;

  @IsNumber()
  @IsOptional()
  blurScore?: number;

  @IsString()
  @IsOptional()
  status?: string;

  @IsString()
  @IsOptional()
  imageUrl?: string;

  @IsString()
  @IsOptional()
  notes?: string;

  @IsNumber()
  @IsOptional()
  latitude?: number;

  @IsNumber()
  @IsOptional()
  longitude?: number;

  @IsNumber()
  @IsOptional()
  accuracyMeters?: number;

  @IsString()
  @IsOptional()
  farmId?: string;
}

export class AddFieldAssessmentDto {
  @IsString()
  @IsNotEmpty()
  crop: string;

  @IsString()
  @IsNotEmpty()
  condition: string;

  @IsString()
  @IsNotEmpty()
  mlPrediction: string;

  @IsNumber()
  @IsNotEmpty()
  mlConfidence: number;

  @IsString()
  @IsNotEmpty()
  severity: string;

  @IsString()
  @IsNotEmpty()
  progressionStatus: string;

  @IsString()
  @IsNotEmpty()
  recommendationSummary: string;

  @IsString()
  @IsNotEmpty()
  actionLevel: string;

  @IsNumber()
  @IsOptional()
  followUpDays?: number = 7;

  @IsString()
  @IsNotEmpty()
  farmerQuestion: string;

  @IsString()
  @IsOptional()
  weatherSnapshot?: string;

  @IsString()
  @IsOptional()
  imagePath?: string;
}

export class AddMessageDto {
  @IsString()
  @IsNotEmpty()
  text: string;

  @IsString()
  @IsNotEmpty()
  sender: string;
}
