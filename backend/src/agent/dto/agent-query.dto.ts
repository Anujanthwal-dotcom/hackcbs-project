import { IsArray, IsNotEmpty, IsObject, IsOptional, IsString } from 'class-validator';

export class AgentMessageItemDto {
  @IsString()
  role: 'user' | 'model';

  @IsString()
  text: string;
}

export class AgentQueryDto {
  @IsString()
  @IsNotEmpty()
  message: string;

  @IsObject()
  @IsOptional()
  context?: Record<string, any>;

  @IsArray()
  @IsOptional()
  history?: AgentMessageItemDto[];
}

export class ConfirmActionDto {
  @IsString()
  @IsNotEmpty()
  actionType: string;

  @IsObject()
  @IsNotEmpty()
  payload: Record<string, any>;
}

