<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'password',
        'language',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function corrections(): HasMany
    {
        return $this->hasMany(CorrectionHistory::class);
    }

    public function translations(): HasMany
    {
        return $this->hasMany(TranslationHistory::class);
    }

    public function subscription(): HasOne
    {
        return $this->hasOne(Subscription::class)->latestOfMany();
    }

    public function usageLogs(): HasMany
    {
        return $this->hasMany(UsageLog::class);
    }

    /**
     * Returns the user's current subscription tier: 'free', 'starter', or 'pro'.
     */
    public function subscriptionTier(): string
    {
        $subscription = $this->subscription;
        if (!$subscription) {
            return 'free';
        }

        if ($subscription->status !== 'active') {
            return 'free';
        }

        if ($subscription->expires_at !== null && $subscription->expires_at->isPast()) {
            return 'free';
        }

        return match ($subscription->plan) {
            'pro_monthly' => 'pro',
            'starter_monthly' => 'starter',
            default => 'free',
        };
    }

    /**
     * Legacy helper — true if the user has any paid plan (starter or pro).
     */
    public function isPro(): bool
    {
        return $this->subscriptionTier() !== 'free';
    }

    /**
     * Daily action limit based on tier.
     */
    public function dailyLimit(): int
    {
        return match ($this->subscriptionTier()) {
            'pro' => 500,
            'starter' => 50,
            default => 10,
        };
    }

    public function todayUsageCount(): int
    {
        return $this->usageLogs()
            ->whereDate('usage_date', today())
            ->count();
    }

    public function canPerformAction(): bool
    {
        return $this->todayUsageCount() < $this->dailyLimit();
    }

    public function remainingActions(): int
    {
        return max(0, $this->dailyLimit() - $this->todayUsageCount());
    }
}
