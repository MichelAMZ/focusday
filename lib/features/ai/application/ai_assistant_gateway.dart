import '../domain/ai_assistant_models.dart';

abstract interface class AiAssistantGateway {
  Future<AiResponse> respond(AiRequest request);
}
