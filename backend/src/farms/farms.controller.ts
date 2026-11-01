import { Body, Controller, Delete, Get, Param, Patch, Post, Request, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { CreateFarmDto, UpdateFarmDto } from './dto/farm.dto.js';
import { FarmsService } from './farms.service.js';

@UseGuards(JwtAuthGuard)
@Controller('farms')
export class FarmsController {
  constructor(private readonly farmsService: FarmsService) {}

  @Post()
  async create(@Request() req: any, @Body() dto: CreateFarmDto) {
    return this.farmsService.create(req.user.id, dto);
  }

  @Get()
  async findAll(@Request() req: any) {
    return this.farmsService.findUserFarms(req.user.id);
  }

  @Get(':id')
  async findOne(@Request() req: any, @Param('id') id: string) {
    return this.farmsService.findOne(req.user.id, id);
  }

  @Patch(':id')
  async update(@Request() req: any, @Param('id') id: string, @Body() dto: UpdateFarmDto) {
    return this.farmsService.update(req.user.id, id, dto);
  }

  @Delete(':id')
  async remove(@Request() req: any, @Param('id') id: string) {
    return this.farmsService.remove(req.user.id, id);
  }
}

