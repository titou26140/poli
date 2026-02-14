<?php

namespace App\Console\Commands;

use App\Models\AiModelConfig;
use Illuminate\Console\Command;

class AiModelCacheClear extends Command
{
    protected $signature = 'ai:clear-model-cache';

    protected $description = 'Clear the cached AI model configurations';

    public function handle(): void
    {
        AiModelConfig::clearCache();
        $this->info('AI model config cache cleared.');

        $configs = AiModelConfig::where('is_active', true)->get();
        $this->table(
            ['Feature', 'Tier', 'Model'],
            $configs->map(fn ($c) => [$c->feature, $c->tier, $c->model_id]),
        );
    }
}
