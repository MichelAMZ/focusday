import { randomUUID } from "node:crypto";
import cors from "cors";
import express, { type NextFunction, type Request, type Response } from "express";
import type { AiService } from "./ai/ai_service.js";
import { AppError } from "./ai/ai_models.js";
import type { FirebaseAuthVerifier } from "./auth/firebase_auth_verifier.js";
import type { AppConfig } from "./config/env.js";
import type { RateLimiter } from "./middleware/rate_limit.js";
import { validateBody } from "./validation.js";

export function createApp(deps: {
  config: AppConfig; auth: FirebaseAuthVerifier; ai: AiService; rateLimiter: RateLimiter;
}) {
  const app = express();
  app.disable("x-powered-by");
  app.use(cors({
    origin(origin, callback) {
      if (!origin || deps.config.allowedOrigins.includes(origin)) return callback(null, true);
      return callback(new AppError(400, "invalid_request"));
    },
  }));
  app.use(express.json({ limit: deps.config.maxContextBytes + deps.config.maxMessageChars + 1024 }));
  app.get("/health", (_request, response) => response.status(200).json({ status: "ok" }));
  app.post("/api/ai/respond", async (request, response, next) => {
    const requestId = randomUUID();
    const started = Date.now();
    let status = 200;
    try {
      const header = request.header("authorization");
      if (!header?.startsWith("Bearer ") || !header.slice(7).trim()) throw new AppError(401, "unauthenticated");
      let identity;
      try { identity = await deps.auth.verifyIdToken(header.slice(7).trim()); }
      catch { throw new AppError(401, "unauthenticated"); }
      if (!deps.rateLimiter.allow(identity.uid)) throw new AppError(429, "rate_limited");
      const body = validateBody(request.body, deps.config);
      const result = await deps.ai.respond(identity.uid, body.message, body.context, body.conversationId);
      response.status(200).json({
        text: result.text,
        ...(result.conversationId ? { conversationId: result.conversationId } : {}),
        ...(result.proposedActions === undefined
          ? {}
          : { proposedActions: result.proposedActions }),
        metadata: { requestId },
      });
    } catch (error) {
      status = error instanceof AppError ? error.status : 500;
      next(error);
    } finally {
      console.info(JSON.stringify({ requestId, durationMs: Date.now() - started, status }));
    }
  });
  app.use((error: unknown, _request: Request, response: Response, _next: NextFunction) => {
    const safe = error instanceof AppError ? error : new AppError(500, "server_error");
    response.status(safe.status).json({ error: { code: safe.code } });
  });
  return app;
}
