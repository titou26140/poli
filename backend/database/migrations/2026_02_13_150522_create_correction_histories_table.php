<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('correction_histories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->text('original_text');
            $table->text('corrected_text');
            $table->text('explanation')->nullable();
            $table->string('language', 10)->nullable();
            $table->boolean('is_favorite')->default(false);
            $table->string('model_used', 50)->default('haiku');
            $table->integer('tokens_used')->default(0);
            $table->timestamps();

            $table->index(['user_id', 'created_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('correction_histories');
    }
};
