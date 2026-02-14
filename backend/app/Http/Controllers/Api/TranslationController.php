<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AiModelConfig;
use App\Models\TranslationHistory;
use App\Models\UsageLog;
use App\Services\AnthropicService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TranslationController extends Controller
{
    private const SUPPORTED_LANGUAGES = [
        'fr', 'en', 'es', 'de', 'it', 'pt', 'nl', 'ru', 'zh',
        'ja', 'ko', 'ar', 'pl', 'tr', 'sv', 'no', 'da', 'fi', 'cs', 'ro',
    ];

    private const FREE_TIER_LANGUAGES = ['fr', 'en', 'es', 'de'];

    public function __construct(
        private AnthropicService $anthropic,
    ) {}

    public function translate(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'text' => 'required|string|max:20000',
            'target_language' => 'required|string|in:' . implode(',', self::SUPPORTED_LANGUAGES),
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

        if (!$user->isPro() && !in_array($validated['target_language'], self::FREE_TIER_LANGUAGES)) {
            return response()->json([
                'error' => 'language_not_available',
                'message' => 'This language requires a Pro subscription.',
                'available_languages' => self::FREE_TIER_LANGUAGES,
            ], 403);
        }

        $maxLength = $user->isPro() ? 20000 : 5000;
        if (mb_strlen($validated['text']) > $maxLength) {
            return response()->json([
                'error' => 'text_too_long',
                'message' => "Text exceeds the {$maxLength} character limit.",
                'limit' => $maxLength,
            ], 422);
        }

        $model = AiModelConfig::resolve('translation', $user->subscriptionTier());

        try {
            $result = $this->anthropic->translate($validated['text'], $validated['target_language'], $model, $userLanguage);
        } catch (\Exception $e) {
            return response()->json([
                'error' => 'ai_error',
                'message' => 'Failed to process translation. Please try again.',
            ], 502);
        }

        $history = TranslationHistory::create([
            'user_id' => $user->id,
            'original_text' => $validated['text'],
            'translated_text' => $result['translated'],
            'source_language' => $result['source_language'],
            'target_language' => $validated['target_language'],
            'tips' => $result['tips'],
            'model_used' => $model,
            'tokens_used' => $result['tokens_used'],
        ]);

        UsageLog::create([
            'user_id' => $user->id,
            'action_type' => 'translation',
            'tokens_used' => $result['tokens_used'],
            'model_used' => $model,
            'usage_date' => today(),
        ]);

        return response()->json([
            'translated' => $result['translated'],
            'source_language' => $result['source_language'],
            'target_language' => $validated['target_language'],
            'tips' => $result['tips'],
            'history_id' => $history->id,
            'remaining_actions' => $user->remainingActions(),
        ]);
    }

    public function languages(Request $request): JsonResponse
    {
        $user = $request->user();
        $isPro = $user ? $user->isPro() : false;

        $languages = collect(self::SUPPORTED_LANGUAGES)->map(fn (string $code) => [
            'code' => $code,
            'available' => $isPro || in_array($code, self::FREE_TIER_LANGUAGES),
            'requires_pro' => !in_array($code, self::FREE_TIER_LANGUAGES),
        ]);

        return response()->json(['languages' => $languages]);
    }
}
