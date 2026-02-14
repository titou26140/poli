<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Subscription extends Model
{
    protected $fillable = [
        'user_id',
        'plan',
        'apple_transaction_id',
        'apple_original_transaction_id',
        'product_id',
        'status',
        'starts_at',
        'expires_at',
        'cancelled_at',
        'receipt_data',
    ];

    protected function casts(): array
    {
        return [
            'starts_at' => 'datetime',
            'expires_at' => 'datetime',
            'cancelled_at' => 'datetime',
            'receipt_data' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function isActive(): bool
    {
        return $this->status === 'active'
            && $this->plan !== 'free'
            && ($this->expires_at === null || $this->expires_at->isFuture());
    }
}
