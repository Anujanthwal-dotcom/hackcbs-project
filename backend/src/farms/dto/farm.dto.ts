import {
  IsArray,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class GeoCoordinateDto {
  @IsNumber()
  @IsNotEmpty()
  latitude: number;

  @IsNumber()
  @IsNotEmpty()
  longitude: number;

  @IsNumber()
  @IsOptional()
  accuracyMeters?: number;

  @IsOptional()
  timestamp?: string;
}

export class UpdateFarmDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => GeoCoordinateDto)
  @IsOptional()
  boundary?: GeoCoordinateDto[];

  @ValidateNested()
  @Type(() => GeoCoordinateDto)
  @IsOptional()
  center?: GeoCoordinateDto;

  @IsNumber()
  @IsOptional()
  areaSquareMeters?: number;

  @IsString()
  @IsOptional()
  cropType?: string;
}

export class CreateFarmDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => GeoCoordinateDto)
  boundary: GeoCoordinateDto[];

  @ValidateNested()
  @Type(() => GeoCoordinateDto)
  center: GeoCoordinateDto;

  @IsNumber()
  @IsOptional()
  areaSquareMeters?: number;

  @IsString()
  @IsOptional()
  cropType?: string;
}

