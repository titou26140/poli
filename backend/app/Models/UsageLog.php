<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UsageLog extends Model
{
    protected $fillable = [
        'user_id',
        'action_type',
        'tokens_used',
        'model_used',
        'usage_date',
    ];

    protected function casts(): array
    {
        return [
            'usage_date' => 'date',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
