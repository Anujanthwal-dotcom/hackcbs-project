import {
  IsBoolean,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';

export class CreateAlertDto {
  @IsString()
  @IsNotEmpty()
  type: string;

  @IsString()
  @IsNotEmpty()
  title: string;

  @IsString()
  @IsNotEmpty()
  message: string;

  @IsString()
  @IsNotEmpty()
  severity: string;

  @IsString()
  @IsOptional()
  farmId?: string;

  @IsString()
  @IsOptional()
  weatherContext?: string;

  @IsString()
  @IsOptional()
  relatedDetectionId?: string;

  @IsBoolean()
  @IsOptional()
  read?: boolean = false;
}

