# FocusDay 15A — AI gateway contract

## Scope

15A defines a read-only assistant boundary. It has no project, task, timer,
notes, settings, storage, or sync mutation capability. Flutter never calls
OpenAI directly and never contains an OpenAI credential or model name.

## Client/backend contract

`POST /api/ai/respond`

- Header: `Authorization: Bearer <Firebase ID token>`
- Content type: `application/json`
- Body: `{ "message": string, "conversationId"?: string, "context": object }`
- Success: `{ "text": string, "conversationId"?: string, "metadata"?: { "requestId"?: string } }`
- Errors: stable codes `unauthenticated`, `unavailable`, `timeout`,
  `rateLimited`, `invalidRequest`, or `serverError`; no upstream payload or
  secret is returned.

The server must verify the Firebase ID token and derive its internal user
identity from that verified token. It must reject oversized messages and
contexts, enforce a timeout, and later enforce per-user quotas/rate limits.

## OpenAI boundary

Only the backend calls the OpenAI Responses API. The model, output limit,
timeout, and `store` setting are server configuration. For 15A the request has
no tools/function calls. The server creates `safety_identifier` from a
server-side keyed, non-reversible pseudonym of the verified user identifier;
it never sends the raw Firebase UID or email. Logs contain request IDs,
latency, result category, and aggregate sizes only—never credentials, tokens,
messages, context, or upstream response bodies.

## Context allowlist

The client serializes only FocusDay language, active project name, that
project's task titles/completion flags, remaining focus seconds, and non-empty
project notes. Project/task IDs, other projects, email, Firebase UID/config,
secrets, and device-local settings are excluded by construction.

## Backend recommendation

No backend exists in this repository. For the V1, use a small separate
Node/TypeScript service behind HTTPS. This keeps OpenAI secrets server-only,
works for Windows and Web, and avoids coupling the current Spark project to a
Firebase Functions deployment or billing-plan change. Firebase Functions is a
reasonable later option if its deployment/billing requirements are accepted.
Whichever host is selected in 15B must provide secret management, Firebase
Admin token verification, HTTPS, request limits, timeouts, and abuse controls.

## 15B implementation

The implementation lives in `server/` and remains independent from Flutter.
It exposes `GET /health` and `POST /api/ai/respond`. The latter verifies the
Bearer token through an injectable Firebase verifier, validates the strict 15A
allowlist, rate-limits by verified UID, derives a 64-character
`safety_identifier` with HMAC-SHA256, then calls an injectable `AiProvider`.

The production adapter uses the OpenAI Responses API with no tools. Its model,
timeout and `store` value are server configuration; V1 recommends
`OPENAI_STORE=false`. Provider errors are converted to stable HTTP errors and
raw provider payloads are never returned.

### Local backend

1. Run `cd server && npm install`.
2. Copy `.env.example` to an ignored `.env`.
3. Configure Firebase Admin application-default credentials.
4. Set a long random `FOCUSDAY_AI_SAFETY_SECRET`.
5. Leave `OPENAI_STORE=false`.
6. For tests, run `npm test`; no OpenAI or Firebase network call is made.
7. For a future real run only, inject `OPENAI_API_KEY` through the hosting
   platform's secret manager and select `OPENAI_MODEL` server-side.

`ALLOWED_ORIGINS` is a comma-separated explicit allowlist. Local defaults
only cover localhost origins. Production must replace them with the deployed
FocusDay Web origin and must not use a permissive wildcard.

The in-memory limiter is suitable only for local/V1 single-instance testing.
Before horizontal scaling, replace it with a shared atomic store. A production
host must also enforce request/body limits at its edge and protect health and
application logs from untrusted fields.

The Flutter `HttpAiAssistantGateway` receives its base URL and HTTP client by
injection. It retrieves the signed-in Firebase user's ID token, sends it as a
Bearer token, and maps the stable HTTP statuses to the provider-independent
15A error categories. It contains no OpenAI key, model, or provider URL.

Nothing is deployed and no real provider call is made in 15B validation.

## 15C read-only interface

The assistant appears as a secondary right panel on wide layouts and as a
separate page opened from the Today header on narrower layouts. Conversation
state is held only by the Riverpod `AiAssistantController`; it is not written
to SharedPreferences, Firestore, or the FocusDay sync layer.

The default development gateway is a deterministic in-memory fake. A future
composition root may override `aiAssistantGatewayProvider` with the 15B HTTP
gateway after a real backend URL and deployment are approved. The interface
does not expose project/task/timer/note mutation actions, and the Responses API
adapter still declares no tools.
