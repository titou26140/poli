<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AiModelConfig;
use App\Models\CorrectionHistory;
use App\Models\UsageLog;
use App\Services\AnthropicService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CorrectionController extends Controller
{
    public function __construct(
        private AnthropicService $anthropic,
    ) {}

    public function correct(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'text' => 'required|string|max:20000',
            'user_language' => 'nullable|string|in:fr,en',
        ]);

        $user = $request->user();

        // Save user language preference for future use (emails, etc.)
        $userLanguage = $validated['user_language'] ?? 'fr';
        if ($user->language !== $userLanguage) {
            $user->update(['language' => $userLanguage]);
        }

        if (!$user->canPerformAction()) {
            return response()->json([
                'error' => 'daily_limit_reached',
                'message' => 'Daily limit reached. Upgrade to Pro!',
                'remaining_actions' => 0,
            ], 429);
        }

        $maxLength = $user->isPro() ? 20000 : 5000;
        if (mb_strlen($validated['text']) > $maxLength) {
            return response()->json([
                'error' => 'text_too_long',
                'message' => "Text exceeds the {$maxLength} character limit.",
                'limit' => $maxLength,
            ], 422);
        }

        $model = AiModelConfig::resolve('correction', $user->subscriptionTier());

        try {
            $result = $this->anthropic->correctGrammar($validated['text'], $model, $userLanguage);
        } catch (\Exception $e) {
            return response()->json([
                'error' => 'ai_error',
                'message' => 'Failed to process correction. Please try again.',
            ], 502);
        }

        $history = CorrectionHistory::create([
            'user_id' => $user->id,
            'original_text' => $validated['text'],
            'corrected_text' => $result['corrected'],
            'explanation' => $result['explanation'],
            'errors' => $result['errors'],
            'language' => $result['language'],
            'model_used' => $model,
            'tokens_used' => $result['tokens_used'],
        ]);

        UsageLog::create([
            'user_id' => $user->id,
            'action_type' => 'correction',
            'tokens_used' => $result['tokens_used'],
            'model_used' => $model,
            'usage_date' => today(),
        ]);

        return response()->json([
            'corrected' => $result['corrected'],
            'explanation' => $result['explanation'],
            'errors' => $result['errors'],
            'language' => $result['language'],
            'has_changes' => $result['corrected'] !== $validated['text'],
            'history_id' => $history->id,
            'remaining_actions' => $user->remainingActions(),
        ]);
    }
}
