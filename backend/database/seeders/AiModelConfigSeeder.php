<?php

namespace Database\Seeders;

use App\Models\AiModelConfig;
use Illuminate\Database\Seeder;

class AiModelConfigSeeder extends Seeder
{
    public function run(): void
    {
        $configs = [
            // Correction
            ['feature' => 'correction', 'tier' => 'free',    'model_id' => 'claude-haiku-4-5-20251001'],
            ['feature' => 'correction', 'tier' => 'starter', 'model_id' => 'claude-haiku-4-5-20251001'],
            ['feature' => 'correction', 'tier' => 'pro',     'model_id' => 'claude-sonnet-4-5-20250929'],

            // Translation
            ['feature' => 'translation', 'tier' => 'free',    'model_id' => 'claude-haiku-4-5-20251001'],
            ['feature' => 'translation', 'tier' => 'starter', 'model_id' => 'claude-haiku-4-5-20251001'],
            ['feature' => 'translation', 'tier' => 'pro',     'model_id' => 'claude-sonnet-4-5-20250929'],
        ];

        foreach ($configs as $config) {
            AiModelConfig::updateOrCreate(
                ['feature' => $config['feature'], 'tier' => $config['tier']],
                ['model_id' => $config['model_id'], 'is_active' => true],
            );
        }
    }
}
