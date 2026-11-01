import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AgentModule } from './agent/agent.module.js';
import { AlertsModule } from './alerts/alerts.module.js';
import { AuthModule } from './auth/auth.module.js';
import { DetectionsModule } from './detections/detections.module.js';
import { FarmsModule } from './farms/farms.module.js';
import { PrismaModule } from './prisma/prisma.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    FarmsModule,
    DetectionsModule,
    AlertsModule,
    AgentModule,
  ],
})
export class AppModule {}
