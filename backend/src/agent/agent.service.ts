import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { AgentQueryDto, ConfirmActionDto } from './dto/agent-query.dto.js';
import { GeminiProvider } from './providers/gemini.provider.js';
import { LlmToolDefinition } from './providers/llm-provider.interface.js';
import { MekoMemoryService } from './services/meko-memory.service.js';
import { TelephonyService } from './services/telephony.service.js';

@Injectable()
export class AgentService {
  private readonly logger = new Logger(AgentService.name);

  // Available agent tools allowlisted for UI interaction
  private readonly toolDefinitions: LlmToolDefinition[] = [
    {
      name: 'navigate_to',
      description: 'Navigates the application to one of the major screens: Scan, Map, Help Desk, or Profile.',
      parameters: {
        type: 'object',
        properties: {
          target_screen: {
            type: 'string',
            description: 'The destination screen: "Scan", "Map", "Help Desk", or "Profile".',
          },
        },
        required: ['target_screen'],
      },
    },
    {
      name: 'highlight_element',
      description: 'Locates and visibly spotlights a registered UI element on the user screen with an animated ring and explanation tooltip.',
      parameters: {
        type: 'object',
        properties: {
          element_id: {
            type: 'string',
            description: 'The stable ID of the registered UI element (e.g., "rename_farm", "map_my_farms", "add_pin_farm", "mark_farm_boundary", "scan_capture_button", "help_desk_refresh").',
          },
          explanation: {
            type: 'string',
            description: 'A brief, friendly explanation telling the farmer how to use this button or element.',
          },
        },
        required: ['element_id'],
      },
    },
    {
      name: 'scroll_to_element',
      description: 'Smoothly scrolls the active view until a specific element is centered and visible.',
      parameters: {
        type: 'object',
        properties: {
          element_id: {
            type: 'string',
            description: 'The stable ID of the registered element to scroll to.',
          },
        },
        required: ['element_id'],
      },
    },
    {
      name: 'explain_element',
      description: 'Provides an educational explanation of what a particular UI element does.',
      parameters: {
        type: 'object',
        properties: {
          element_id: {
            type: 'string',
            description: 'The element ID to explain.',
          },
        },
        required: ['element_id'],
      },
    },
    {
      name: 'prepare_action',
      description: 'Prepares a sensitive or data-modifying operation (e.g., renaming a farm, editing records) and queues it for explicit farmer confirmation.',
      parameters: {
        type: 'object',
        properties: {
          action_type: {
            type: 'string',
            description: 'The type of action, e.g. "rename_farm" or "update_crop".',
          },
          description: {
            type: 'string',
            description: 'Human-readable summary of the exact change proposed.',
          },
          payload: {
            type: 'object',
            description: 'Key-value parameters required to execute the action upon approval.',
          },
        },
        required: ['action_type', 'description'],
      },
    },
    {
      name: 'rename_farm',
      description: 'Prepares a farm renaming operation in the KisaanBandhu app. Can target a specific farm by its current name, index (e.g. "Farm 1"), or ID, and change it to the proposed new name. Triggers an in-app confirmation card.',
      parameters: {
        type: 'object',
        properties: {
          target_farm: {
            type: 'string',
            description: 'The existing farm to rename (e.g. "Farm 1", "Farm 4", "Yash", or the farm ID). If not specified or user says "my farm", use the active farm.',
          },
          new_name: {
            type: 'string',
            description: 'The proposed new name for the farm (e.g. "Pratyush", "Yash Farm").',
          },
        },
        required: ['new_name'],
      },
    },
  ];

  constructor(
    private readonly prisma: PrismaService,
    private readonly gemini: GeminiProvider,
    private readonly meko: MekoMemoryService,
    private readonly telephony: TelephonyService,
  ) {}

  /**
   * Health check for online AI capabilities
   */
  getHealthStatus() {
    return {
      available: this.gemini.isConfigured(),
      geminiConfigured: this.gemini.isConfigured(),
      mekoConfigured: this.meko.isConfigured(),
      telephonyConfigured: this.telephony.isVapiConfigured() || this.telephony.isTwilioConfigured(),
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Main context-aware query handler for the Ambient Mascot Agent
   */
  async handleQuery(userId: string, dto: AgentQueryDto) {
    // 1. Fetch canonical database records for this user (never trust client blindly)
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { name: true, preferredLanguage: true },
    });

    const farms = await this.prisma.farm.findMany({
      where: { userId },
      select: { id: true, name: true, cropType: true, areaSquareMeters: true },
      take: 5,
    });

    const recentDetections = await this.prisma.detection.findMany({
      where: { userId },
      select: { id: true, crop: true, condition: true, confidence: true, latestSeverity: true },
      orderBy: { createdAt: 'desc' },
      take: 4,
    });

    const recentAlerts = await this.prisma.alert.findMany({
      where: { userId },
      select: { id: true, title: true, type: true, severity: true },
      orderBy: { createdAt: 'desc' },
      take: 3,
    });

    // 2. Fetch persistent conversational memories from Meko
    const memories = await this.meko.getMemories(userId, dto.message);

    // 3. Extract UI & Navigation context from the incoming snapshot
    const uiContext = dto.context || {};
    const currentScreen = uiContext.application?.currentScreen || 'Unknown';
    const selectedFarm = uiContext.farm || null;
    const selectedDetection = uiContext.detection || null;

    // 4. Construct System Prompt grounded in actual context & persona
    const systemPrompt = `
You are "Krishi Mitra" (कृषि मित्र / बन्धु), the intelligent, context-aware agricultural companion and ambient mascot of the KisaanBandhu (किसान बंधु) application.
You are assisting the farmer: ${user?.name || 'Farmer'}.

=== STRICT DOMAIN & SCOPE GUARDRAILS (CRITICAL) ===
1. You are EXCLUSIVELY an assistant for KisaanBandhu and Indian Agriculture.
2. PERMITTED TOPICS:
   - Operating, navigating, and guiding the user through the KisaanBandhu app (Scan, Map, Help Desk, Profile, offline mode, farm boundaries, reports, settings).
   - Indian agriculture, crop diseases, pest diagnosis & treatment, soil health, fertilizers, irrigation, weather impact, and government farming schemes (PM-Kisan, PMFBY, KCC).
3. STRICTLY FORBIDDEN TOPICS:
   - General world trivia, movies, coding/programming, non-farming politics, video games, general entertainment, homework, or anything unrelated to farming/this app.
   - If the user asks anything outside this scope, you MUST POLITELY DECLINE in warm, respectful Hindi:
     "माफ़ कीजिए किसान भाई, मैं केवल किसान बंधु ऐप और खेती-किसानी से जुड़े विषयों पर आपकी सहायता कर सकता हूँ। कृपया अपनी फसल, खेत या ऐप के उपयोग से संबंधित प्रश्न पूछें।"

=== COMPLETE KISAANBANDHU APP KNOWLEDGE BASE ===
- 📸 "Scan" (स्कैन): Crop pest and disease diagnosis using camera / gallery photos. Features live camera preview, bounding boxes, instant diagnosis, severity rating, and chemical/biological remedies. Known elements: "scan_capture_button" (कैमरा बटन), "scan_toggle_live" (लाइव स्कैन टॉगल).
- 🗺️ "Map" (खेत / मैप): Interactive farm mapping using Mapbox with satellite tiles. Allows farmers to mark farm boundaries by GPS pin or drawing polygon corners, calculate acreage/area, rename farms, and view farm health.
  Known elements:
  * "rename_farm": Edit/rename currently selected farm (पेंसिल/एडिट आइकन)
  * "map_my_farms": Drawer listing all saved farms (मेरे खेत)
  * "map_fit_farm": Center and zoom camera onto active farm boundary (खेत पर ज़ूम करें)
  * "add_pin_farm": Add farm marker at current live GPS coordinates (यहाँ खेत जोड़ें)
  * "mark_farm_boundary": Draw or adjust field boundary corners (सीमा रेखा खींचें)
- 🎧 "Help Desk" (सहायता केंद्र): Krishi advisory, expert consultations, disease outbreak alerts, weather forecast, government subsidy schemes. Known element: "help_desk_refresh".
- 👤 "Profile" (प्रोफ़ाइल): Farmer profile, history of diagnoses ("profile_history"), edit farmer name ("profile_edit_name"), language selector, and logout ("profile_sign_out").

=== CRITICAL IN-APP DEFINITION: WHAT IS A "FARM" & "RENAME"? ===
- In KisaanBandhu, a "farm" (खेत) is simply a user-drawn boundary polygon or GPS pin saved on the Map screen (e.g. "Farm 1", "Farm 4", "Yash").
- "Renaming a farm" means updating the display title of that in-app map polygon record.
- It is NEVER a real-world legal business registration, corporate rebranding, deed modification, or permit process!
- STRICT PROHIBITION: DO NOT EVER discuss government permits, legal deeds, business registration, supplier communications, or real-world bureaucracy when a user asks to rename or change a farm name.
- Whether the farmer asks in English ("change farm 1 name to Yash", "rename my farm to Pratyush", "change farm name") or in Hindi ("खेत 1 का नाम यश कर दो", "खेत का नाम बदलें"), you must IMMEDIATELY recognize this as an in-app map record change and call the 'rename_farm' tool!

=== CANONICAL FARM DATA (FROM DATABASE) ===
- Registered Farms: ${farms.length > 0 ? JSON.stringify(farms) : 'No farms saved yet.'}
- Recent Crop Diagnoses: ${recentDetections.length > 0 ? JSON.stringify(recentDetections) : 'No past diagnoses.'}
- Recent Alerts: ${recentAlerts.length > 0 ? JSON.stringify(recentAlerts) : 'No active alerts.'}

=== CURRENT APPLICATION CONTEXT ===
- User's Current Screen: "${currentScreen}" (ALWAYS acknowledge what screen the user is currently on!)
- Selected Farm: ${selectedFarm ? JSON.stringify(selectedFarm) : (farms.length > 0 ? JSON.stringify(farms[0]) : 'None currently selected')}
- Selected Field Point: ${selectedDetection ? JSON.stringify(selectedDetection) : 'None'}
- Recent App Activity: ${JSON.stringify(uiContext.recentActivity || [])}

=== BEHAVIOR, CONTEXT-AWARENESS & AUTONOMOUS ACTIONS ===
1. PRIMARY LANGUAGE (HINDI-FIRST ALWAYS):
   - ALWAYS formulate all answers in clear, natural, warm, respectful Hindi (Devanagari script: हिन्दी).
   - Greet warmly: "नमस्ते किसान भाई!", "जी किसान भाई!", etc.
   - Use simple agricultural Hindi terms ("खेत", "फसल", "रोग", "दवाई", "खाद").
2. CONTEXT AWARENESS & SCREEN GUIDANCE (HOW TO RENAME OR PERFORM ACTIONS):
   - If the user asks HOW to rename their farm ("how to rename", "खेत का नाम कैसे बदलें", "rename kaise karein"):
     * If user is ALREADY on "Map":
       Call 'highlight_element' (element_id: "rename_farm", explanation: "यहाँ टैप करके खेत का नाम बदलें").
       Explain in warm Hindi: "हाँ किसान भाई! क्या मैं आपको स्क्रीन पर गाइड करूँ और बटन मार्क कर दूँ? मैंने ऊपर पेंसिल आइकन को हाइलाइट कर दिया है ताकि आप उस पर क्लिक करके नाम बदल सकें। या फिर आप मुझे सीधे बता सकते हैं: 'खेत 1 का नाम नया नाम रख दो' और मैं खुद नाम बदल दूँगा!"
     * If user is NOT on "Map" (e.g. they are on "${currentScreen}"):
       Call BOTH 'navigate_to' (target_screen: "Map") AND 'highlight_element' (element_id: "rename_farm", explanation: "यहाँ टैप करके खेत का नाम बदलें").
       Explain in Hindi: "हाँ किसान भाई! चलिए मैं आपको Map स्क्रीन पर ले चलता हूँ और खेत का नाम बदलने वाले बटन को मार्क कर देता हूँ।"
3. AUTOMATIC TASK EXECUTION & SPECIFIC FARM TARGETING:
   - If the user directly instructs you to change/rename a farm (e.g. "change farm 1 name to Yash", "खेत 1 का नाम प्रत्यूष कर दो", "rename Yash to Pratyush", "rename farm to Green Acres"):
     * Identify the target farm from the Registered Farms list. If the user said "farm 1", target_farm is "Farm 1". If user said "Yash", target_farm is "Yash".
     * Call 'rename_farm' with {"target_farm": "<target_farm_name>", "new_name": "<new_name>"}.
     * If not already on Map screen, also call 'navigate_to' {"target_screen": "Map"}.
     * Reply in Hindi: "मैंने आपके खेत '<target_farm_name>' का नाम '<new_name>' करने की तैयारी कर ली है। कृपया नीचे 'Confirm & Save' पर टैप करके पुष्टि करें।"
4. GUIDANCE ON ANY OTHER SCREEN:
   - If user asks how to scan a crop: Call 'navigate_to' {"target_screen": "Scan"}, call 'highlight_element' {"element_id": "scan_capture_button", "explanation": "यहाँ टैप करके पत्ती की फोटो लें"}.
   - If user asks for expert help or schemes: Call 'navigate_to' {"target_screen": "Help Desk"}.
`.trim();

    // 5. Call LLM Provider (Gemini)
    const history = (dto.history || []).map((h) => ({
      role: h.role,
      text: h.text,
    }));

    const llmResponse = await this.gemini.generateResponse(
      systemPrompt,
      history,
      dto.message,
      this.toolDefinitions,
    );

    // Synthesize warm Hindi reply if Gemini executed tool calls with empty text
    let finalReply = (llmResponse.text || '').trim();
    if (!finalReply && llmResponse.toolCalls && llmResponse.toolCalls.length > 0) {
      const tc = llmResponse.toolCalls[0];
      if (tc.tool === 'rename_farm') {
        finalReply = `मैंने आपके खेत का नाम "${tc.parameters?.new_name || 'नया नाम'}" करने की तैयारी कर ली है। कृपया नीचे 'Confirm & Save' पर टैप करके पुष्टि करें।`;
      } else if (tc.tool === 'navigate_to') {
        finalReply = `किसान भाई, मैं आपको ${tc.parameters?.target_screen || 'उस'} स्क्रीन पर ले चल रहा हूँ।`;
      } else if (tc.tool === 'highlight_element') {
        finalReply = `किसान भाई, मैंने आपकी स्क्रीन पर संबंधित बटन को हाइलाइट कर दिया है ताकि आप आसानी से देख सकें।`;
      } else {
        finalReply = `जी किसान भाई, मैंने आपके कहे अनुसार कार्य शुरू कर दिया है।`;
      }
    }

    // 6. Asynchronously store valuable conversation memory in Meko
    if (dto.message.length > 10) {
      this.meko.storeMemory(userId, `Farmer asked: "${dto.message}"`).catch(() => {});
    }

    return {
      success: true,
      reply: finalReply,
      toolCalls: llmResponse.toolCalls || [],
      isOfflineFallback: !this.gemini.isConfigured(),
    };
  }

  /**
   * Executes a confirmed Human-in-the-Loop action
   */
  async handleConfirmAction(userId: string, dto: ConfirmActionDto) {
    this.logger.log(`Executing confirmed action for user ${userId}: ${dto.actionType}`);

    switch (dto.actionType) {
      case 'rename_farm': {
        const farmId = dto.payload.farmId;
        const newName = dto.payload.newName?.trim();

        if (!farmId || !newName) {
          throw new BadRequestException('farmId and newName are required');
        }

        // Verify farm ownership
        const farm = await this.prisma.farm.findFirst({
          where: { id: farmId, userId },
        });

        if (!farm) {
          throw new NotFoundException('Farm not found or access denied');
        }

        const updated = await this.prisma.farm.update({
          where: { id: farmId },
          data: { name: newName },
        });

        return {
          success: true,
          message: `Farm "${farm.name}" successfully renamed to "${updated.name}".`,
          data: updated,
        };
      }

      default:
        throw new BadRequestException(`Unsupported action type: ${dto.actionType}`);
    }
  }
}

