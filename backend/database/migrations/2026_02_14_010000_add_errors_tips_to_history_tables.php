<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('correction_histories', function (Blueprint $table) {
            $table->json('errors')->nullable()->after('explanation');
        });

        Schema::table('translation_histories', function (Blueprint $table) {
            $table->json('tips')->nullable()->after('target_language');
        });
    }

    public function down(): void
    {
        Schema::table('correction_histories', function (Blueprint $table) {
            $table->dropColumn('errors');
        });

        Schema::table('translation_histories', function (Blueprint $table) {
            $table->dropColumn('tips');
        });
    }
};
