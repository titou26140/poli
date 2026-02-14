<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CorrectionHistory;
use App\Models\TranslationHistory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class HistoryController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'type' => 'nullable|string|in:corrections,translations',
            'search' => 'nullable|string|max:255',
            'per_page' => 'nullable|integer|min:1|max:100',
        ]);

        $user = $request->user();
        $perPage = $validated['per_page'] ?? 20;
        $search = $validated['search'] ?? null;
        $type = $validated['type'] ?? null;

        $results = collect();

        if ($type !== 'translations') {
            $corrections = $user->corrections()
                ->when($search, fn ($q) => $q->where('original_text', 'like', "%{$search}%")
                    ->orWhere('corrected_text', 'like', "%{$search}%"))
                ->latest()
                ->limit($perPage)
                ->get()
                ->map(fn ($c) => [
                    'id' => $c->id,
                    'type' => 'correction',
                    'original_text' => $c->original_text,
                    'result_text' => $c->corrected_text,
                    'explanation' => $c->explanation,
                    'errors' => $c->errors ?? [],
                    'language' => $c->language,
                    'is_favorite' => $c->is_favorite,
                    'created_at' => $c->created_at->toISOString(),
                ]);
            $results = $results->merge($corrections);
        }

        if ($type !== 'corrections') {
            $translations = $user->translations()
                ->when($search, fn ($q) => $q->where('original_text', 'like', "%{$search}%")
                    ->orWhere('translated_text', 'like', "%{$search}%"))
                ->latest()
                ->limit($perPage)
                ->get()
                ->map(fn ($t) => [
                    'id' => $t->id,
                    'type' => 'translation',
                    'original_text' => $t->original_text,
                    'result_text' => $t->translated_text,
                    'source_language' => $t->source_language,
                    'target_language' => $t->target_language,
                    'tips' => $t->tips ?? [],
                    'is_favorite' => $t->is_favorite,
                    'created_at' => $t->created_at->toISOString(),
                ]);
            $results = $results->merge($translations);
        }

        $sorted = $results->sortByDesc('created_at')->values()->take($perPage);

        return response()->json(['history' => $sorted]);
    }

    public function toggleFavorite(Request $request, string $type, int $id): JsonResponse
    {
        $user = $request->user();

        $model = match ($type) {
            'correction' => CorrectionHistory::where('user_id', $user->id)->findOrFail($id),
            'translation' => TranslationHistory::where('user_id', $user->id)->findOrFail($id),
            default => abort(404),
        };

        $model->is_favorite = !$model->is_favorite;
        $model->save();

        return response()->json(['is_favorite' => $model->is_favorite]);
    }

    public function destroy(Request $request, string $type, int $id): JsonResponse
    {
        $user = $request->user();

        $model = match ($type) {
            'correction' => CorrectionHistory::where('user_id', $user->id)->findOrFail($id),
            'translation' => TranslationHistory::where('user_id', $user->id)->findOrFail($id),
            default => abort(404),
        };

        $model->delete();

        return response()->json(['message' => 'Deleted']);
    }
}
