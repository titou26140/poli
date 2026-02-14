<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CorrectionController;
use App\Http\Controllers\Api\HistoryController;
use App\Http\Controllers\Api\SubscriptionController;
use App\Http\Controllers\Api\TranslationController;
use Illuminate\Support\Facades\Route;

// Public routes
Route::post('/auth/register', [AuthController::class, 'register']);
Route::post('/auth/login', [AuthController::class, 'login']);

// Protected routes (require Sanctum token)
Route::middleware('auth:sanctum')->group(function () {
    // Auth
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::get('/auth/me', [AuthController::class, 'me']);

    // Core features
    Route::post('/correct', [CorrectionController::class, 'correct']);
    Route::post('/translate', [TranslationController::class, 'translate']);
    Route::get('/languages', [TranslationController::class, 'languages']);

    // History
    Route::get('/history', [HistoryController::class, 'index']);
    Route::patch('/history/{type}/{id}/favorite', [HistoryController::class, 'toggleFavorite'])
        ->whereIn('type', ['correction', 'translation']);
    Route::delete('/history/{type}/{id}', [HistoryController::class, 'destroy'])
        ->whereIn('type', ['correction', 'translation']);

    // Subscription
    Route::get('/subscription/status', [SubscriptionController::class, 'status']);
    Route::post('/subscription/verify', [SubscriptionController::class, 'verify']);
    Route::post('/subscription/cancel', [SubscriptionController::class, 'cancel']);
});
