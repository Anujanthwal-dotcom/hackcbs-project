import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module.js';
import { AgentController } from './agent.controller.js';
import { AgentService } from './agent.service.js';
import { GeminiProvider } from './providers/gemini.provider.js';
import { MekoMemoryService } from './services/meko-memory.service.js';
import { TelephonyService } from './services/telephony.service.js';

@Module({
  imports: [PrismaModule],
  controllers: [AgentController],
  providers: [AgentService, GeminiProvider, MekoMemoryService, TelephonyService],
  exports: [AgentService],
})
export class AgentModule {}

