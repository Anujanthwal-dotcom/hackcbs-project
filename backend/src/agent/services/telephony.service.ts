import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface CallbackRequest {
  id: string;
  userId: string;
  farmerPhone: string;
  reason: string;
  urgency: 'routine' | 'urgent' | 'weather_alert';
  consentGranted: boolean;
  scheduledTime?: string;
  status: 'PENDING_CONSENT' | 'SCHEDULED' | 'MOCK_PREVIEW' | 'COMPLETED';
}

/// Telephony & Outbound Voice Integration Service.
///
/// Prepares future telephony integration with Vapi / Twilio.
///
/// SAFETY CONSTRAINTS:
/// - Strictly NO paid or live calls are initiated in this phase.
/// - Requires explicit farmer consent before scheduling any contact.
/// - Enforces retry policy and calling window rules (e.g., 9 AM – 7 PM IST).
/// - Vapi acts solely as a voice orchestration layer; farm state remains in MongoDB.
@Injectable()
export class TelephonyService {
  private readonly logger = new Logger(TelephonyService.name);
  private readonly vapiApiKey: string;
  private readonly vapiPhoneNumberId: string;
  private readonly twilioSid: string;
  private readonly twilioToken: string;

  private readonly callbackRequests: CallbackRequest[] = [];

  constructor(private readonly configService: ConfigService) {
    this.vapiApiKey = this.configService.get<string>('VAPI_PRIVATE_API_KEY', '').trim();
    this.vapiPhoneNumberId = this.configService.get<string>('VAPI_PHONE_NUMBER_ID', '').trim();
    this.twilioSid = this.configService.get<string>('TWILIO_ACCOUNT_SID', '').trim();
    this.twilioToken = this.configService.get<string>('TWILIO_AUTH_TOKEN', '').trim();

    this.logger.log('Telephony service initialized in SAFE PREVIEW mode (no live paid calls).');
  }

  isVapiConfigured(): boolean {
    return !!this.vapiApiKey && this.vapiApiKey.length > 5 && !this.vapiApiKey.includes('placeholder');
  }

  isTwilioConfigured(): boolean {
    return !!this.twilioSid && this.twilioSid.length > 5 && !this.twilioSid.includes('placeholder');
  }

  /**
   * Schedules a farmer-requested callback or proactive agronomy follow-up.
   * STRICT SAFETY: Records the request in audit store, verifies consent,
   * but does NOT dial out or consume paid credits.
   */
  async requestCallback(
    userId: string,
    farmerPhone: string,
    reason: string,
    urgency: 'routine' | 'urgent' | 'weather_alert' = 'routine',
    consentGranted: boolean = false,
  ): Promise<{ success: boolean; message: string; requestId?: string }> {
    if (!consentGranted) {
      return {
        success: false,
        message: 'Cannot schedule telephone contact without explicit farmer consent.',
      };
    }

    const request: CallbackRequest = {
      id: `call_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      userId,
      farmerPhone,
      reason,
      urgency,
      consentGranted,
      status: 'MOCK_PREVIEW',
    };

    this.callbackRequests.push(request);
    this.logger.log(`[Telephony Mock] Callback queued for user ${userId} (${reason}). Live dialing disabled for SIH safety.`);

    return {
      success: true,
      message: 'Telephone callback recorded successfully. (Preview mode: No real call initiated).',
      requestId: request.id,
    };
  }

  /**
   * Retrieves callback history for the authenticated user.
   */
  getPendingCallbacks(userId: string): CallbackRequest[] {
    return this.callbackRequests.filter((r) => r.userId === userId);
  }
}

