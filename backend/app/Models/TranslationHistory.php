<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TranslationHistory extends Model
{
    protected $fillable = [
        'user_id',
        'original_text',
        'translated_text',
        'source_language',
        'target_language',
        'tips',
        'is_favorite',
        'model_used',
        'tokens_used',
    ];

    protected function casts(): array
    {
        return [
            'is_favorite' => 'boolean',
            'tips' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
