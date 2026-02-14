<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CorrectionHistory extends Model
{
    protected $fillable = [
        'user_id',
        'original_text',
        'corrected_text',
        'explanation',
        'errors',
        'language',
        'is_favorite',
        'model_used',
        'tokens_used',
    ];

    protected function casts(): array
    {
        return [
            'is_favorite' => 'boolean',
            'errors' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
