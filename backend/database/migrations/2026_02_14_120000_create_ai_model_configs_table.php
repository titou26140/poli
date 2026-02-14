<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ai_model_configs', function (Blueprint $table) {
            $table->id();
            $table->string('feature', 30);       // 'correction', 'translation'
            $table->string('tier', 20);           // 'free', 'starter', 'pro'
            $table->string('model_id', 100);      // e.g. 'claude-haiku-4-5-20251001'
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->unique(['feature', 'tier']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ai_model_configs');
    }
};
