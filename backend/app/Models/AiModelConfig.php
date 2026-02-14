<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;

class AiModelConfig extends Model
{
    protected $fillable = [
        'feature',
        'tier',
        'model_id',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    /**
     * Resolve the model ID for a given feature and tier.
     * Falls back to 'free' tier if the specific tier has no config,
     * then falls back to a hardcoded default.
     */
    public static function resolve(string $feature, string $tier): string
    {
        $cacheKey = "ai_model:{$feature}:{$tier}";

        return Cache::remember($cacheKey, now()->addHour(), function () use ($feature, $tier) {
            $config = static::where('feature', $feature)
                ->where('tier', $tier)
                ->where('is_active', true)
                ->first();

            if ($config) {
                return $config->model_id;
            }

            // Fallback: try 'free' tier
            if ($tier !== 'free') {
                $fallback = static::where('feature', $feature)
                    ->where('tier', 'free')
                    ->where('is_active', true)
                    ->first();

                if ($fallback) {
                    return $fallback->model_id;
                }
            }

            // Ultimate fallback
            return 'claude-haiku-4-5-20251001';
        });
    }

    /**
     * Clear the cached model configs. Call this after updating the DB.
     */
    public static function clearCache(): void
    {
        $features = ['correction', 'translation'];
        $tiers = ['free', 'starter', 'pro'];

        foreach ($features as $feature) {
            foreach ($tiers as $tier) {
                Cache::forget("ai_model:{$feature}:{$tier}");
            }
        }
    }
}
