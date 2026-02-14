<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Subscription;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SubscriptionController extends Controller
{
    public function status(Request $request): JsonResponse
    {
        $user = $request->user();
        $subscription = $user->subscription;

        return response()->json([
            'is_pro' => $user->isPro(),
            'tier' => $user->subscriptionTier(),
            'plan' => $subscription?->plan ?? 'free',
            'status' => $subscription?->status ?? 'active',
            'expires_at' => $subscription?->expires_at?->toISOString(),
            'remaining_actions' => $user->remainingActions(),
            'today_usage' => $user->todayUsageCount(),
            'daily_limit' => $user->dailyLimit(),
        ]);
    }

    public function verify(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'transaction_id' => 'required|string',
            'original_transaction_id' => 'required|string',
            'product_id' => 'required|string|in:com.poli.starter.monthly,com.poli.pro.monthly',
            'receipt_data' => 'nullable|string',
        ]);

        $user = $request->user();

        // TODO: Verify the receipt with Apple's App Store Server API
        // For now, trust the client (development only)
        $plan = str_contains($validated['product_id'], 'pro') ? 'pro_monthly' : 'starter_monthly';
        $duration = 30;

        $subscription = Subscription::updateOrCreate(
            [
                'user_id' => $user->id,
                'apple_original_transaction_id' => $validated['original_transaction_id'],
            ],
            [
                'plan' => $plan,
                'apple_transaction_id' => $validated['transaction_id'],
                'product_id' => $validated['product_id'],
                'status' => 'active',
                'starts_at' => now(),
                'expires_at' => now()->addDays($duration),
                'receipt_data' => !empty($validated['receipt_data']) ? ['raw' => $validated['receipt_data']] : null,
            ]
        );

        $tier = str_contains($plan, 'pro') ? 'pro' : 'starter';

        return response()->json([
            'is_pro' => true,
            'tier' => $tier,
            'plan' => $plan,
            'expires_at' => $subscription->expires_at->toISOString(),
            'daily_limit' => $tier === 'pro' ? 500 : 50,
            'message' => 'Subscription activated successfully.',
        ]);
    }

    public function cancel(Request $request): JsonResponse
    {
        $user = $request->user();
        $subscription = $user->subscription;

        if (!$subscription || $subscription->plan === 'free') {
            return response()->json([
                'error' => 'no_subscription',
                'message' => 'No active subscription to cancel.',
            ], 404);
        }

        $subscription->update([
            'status' => 'cancelled',
            'cancelled_at' => now(),
        ]);

        return response()->json([
            'message' => 'Subscription cancelled. Access continues until expiry.',
            'expires_at' => $subscription->expires_at?->toISOString(),
        ]);
    }
}
