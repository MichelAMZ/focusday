import OpenAI from "openai";
import { AiService } from "../ai/ai_service.js";
import { OpenAiResponsesProvider, type OpenAiResponsesClient } from "../ai/openai_responses_provider.js";
import { loadConfig } from "../config/env.js";

// Synthetic fixture only. This identity is NOT a Firebase UID.
const localIdentity = "focusday-local-readonly-fixture";
const message = "Résume en une phrase le projet actif et indique la prochaine tâche non terminée.";
const context = {
  language: "fr", focusRemainingSeconds: 1200,
  activeProject: {
    name: "Préparer une présentation",
    tasks: [
      { title: "Choisir le sujet", completed: true },
      { title: "Rédiger le plan", completed: false },
    ],
    notes: "Présentation de cinq minutes.",
  },
};

export interface SafeOpenAiDiagnostic {
  status?: number;
  type?: string;
  code?: string;
  request_id?: string;
}

export function safeOpenAiDiagnostic(error: unknown, secrets: string[] = []): SafeOpenAiDiagnostic {
  if (!(error instanceof OpenAI.APIError)) return {};
  const diagnostic: SafeOpenAiDiagnostic = {};
  if (Number.isInteger(error.status) && error.status! >= 400 && error.status! <= 599) {
    diagnostic.status = error.status;
  }
  const safeString = (value: unknown, pattern: RegExp): value is string =>
    typeof value === "string" && pattern.test(value) &&
    !secrets.some(secret => secret.length > 0 && value.includes(secret));
  if (safeString(error.type, /^[a-z][a-z0-9_]{0,63}$/)) diagnostic.type = error.type;
  if (safeString(error.code, /^[a-z][a-z0-9_]{0,63}$/)) diagnostic.code = error.code;
  if (safeString(error.requestID, /^req_[A-Za-z0-9_-]{1,128}$/)) diagnostic.request_id = error.requestID;
  return diagnostic;
}

export class ReadonlySmokeFailure extends Error {
  constructor(message: string, public readonly diagnostic: SafeOpenAiDiagnostic) {
    super(message);
  }
}

function safeApiFailure(error: unknown): string {
  if (error instanceof OpenAI.APIConnectionTimeoutError) return "Délai OpenAI dépassé ; aucun retry effectué.";
  if (error instanceof OpenAI.APIConnectionError) return "Connexion OpenAI impossible.";
  if (error instanceof OpenAI.APIError) {
    if (error.status === 429) return "Quota, facturation ou limite de débit OpenAI : vérifier le compte avant de réessayer.";
    if (error.status === 401) return "Authentification OpenAI refusée ; vérifier la clé localement.";
    if (error.status === 403 || error.status === 404) return "Accès au modèle ou au projet OpenAI refusé ou indisponible.";
    if (error.status === 400) return "Requête OpenAI refusée ; vérifier le support du modèle et du schéma.";
    return "Erreur HTTP OpenAI ; aucun détail fournisseur journalisé.";
  }
  return "Réponse invalide ou non read-only ; aucune action exécutée.";
}

export async function runReadonlySmoke(env: NodeJS.ProcessEnv, injectedSdk?: OpenAI) {
  // Validate before constructing a client or attempting a request.
  const config = loadConfig(env);
  if (!config.openAiApiKey.trim() || config.openAiApiKey.includes("replace-with") ||
      config.safetySecret.length < 16 || config.safetySecret.includes("replace-with")) {
    throw new Error("Configuration locale absente : OPENAI_API_KEY et FOCUSDAY_AI_SAFETY_SECRET requis.");
  }
  if (config.openAiModel !== "gpt-5.6-luna" || env.OPENAI_STORE !== "false") {
    throw new Error("Ce test exige OPENAI_MODEL=gpt-5.6-luna et OPENAI_STORE=false.");
  }
  const sdk = injectedSdk ?? new OpenAI({
    apiKey: config.openAiApiKey, timeout: config.openAiTimeoutMs,
    maxRetries: 0, logLevel: "off", baseURL: "https://api.openai.com/v1",
  });
  let httpStatus: number | undefined;
  let sent = false;
  let failure: string | undefined;
  let diagnostic: SafeOpenAiDiagnostic = {};
  const client: OpenAiResponsesClient = {
    responses: {
      async create(body, options) {
        if (sent) throw new Error("Un seul appel est autorisé.");
        if (body.model !== config.openAiModel || body.store !== false ||
            !/^[a-f0-9]{64}$/.test(body.safety_identifier ?? "") ||
            body.input !== JSON.stringify({ message, context: { ...context, activeProject: {
              ...context.activeProject, tasks: context.activeProject.tasks.map((task, index) =>
                ({ ...task, taskId: `focusday_task_${index}` })),
            } } })) {
          throw new Error("Contrôle de la requête read-only échoué.");
        }
        sent = true;
        try {
          const result = await sdk.responses.create({
            ...body,
            instructions: body.instructions + "\nFor this read-only test, return only a summary. proposedActions MUST be [].",
            text: { format: {
              type: "json_schema", name: "focusday_readonly", strict: true,
              schema: {
                type: "object", additionalProperties: false,
                required: ["message", "proposedActions"],
                properties: {
                  message: { type: "string" },
                  proposedActions: { type: "array", items: { type: "string" }, maxItems: 0 },
                },
              },
            } },
          }, options).withResponse();
          httpStatus = result.response.status;
          return result.data;
        } catch (error) {
          diagnostic = safeOpenAiDiagnostic(error, [config.openAiApiKey, config.safetySecret]);
          failure = safeApiFailure(error);
          throw error;
        }
      },
    },
  };
  const provider = new OpenAiResponsesProvider({
    apiKey: config.openAiApiKey, model: config.openAiModel,
    timeoutMs: config.openAiTimeoutMs, store: false,
  }, client);
  try {
    const result = await new AiService(provider, config.safetySecret)
      .respond(localIdentity, message, context);
    if (!Array.isArray(result.proposedActions) || result.proposedActions.length !== 0 ||
        httpStatus === undefined || httpStatus < 200 || httpStatus >= 300) {
      throw new Error("Invalid read-only response");
    }
    // Never return model text, request IDs, identity, key, or raw error to the logger.
    return {
      responsesHttpStatus: httpStatus, backendValidation: "PASS", model: config.openAiModel,
      textReceived: true, proposedActionsReceived: false, actionExecuted: false,
      safetyIdentifierPresent: true, rawFirebaseUidSent: false, store: false,
    };
  } catch {
    throw new ReadonlySmokeFailure(
      failure ?? "Réponse invalide ou non read-only ; aucune action exécutée.", diagnostic,
    );
  }
}
