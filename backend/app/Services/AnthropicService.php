<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class AnthropicService
{
    private string $apiKey;
    private string $endpoint;
    private string $apiVersion;

    public function __construct()
    {
        $this->apiKey = config('services.anthropic.api_key');
        $this->endpoint = config('services.anthropic.endpoint', 'https://api.anthropic.com/v1/messages');
        $this->apiVersion = config('services.anthropic.version', '2023-06-01');
    }

    /**
     * Send a message to the Anthropic API with structured JSON output.
     */
    public function sendMessage(
        string $system,
        string $userMessage,
        string $model = 'claude-haiku-4-5-20251001',
        int $maxTokens = 4096,
        ?array $outputSchema = null,
    ): array {
        $payload = [
            'model' => $model,
            'max_tokens' => $maxTokens,
            'system' => $system,
            'messages' => [
                ['role' => 'user', 'content' => $userMessage],
            ],
        ];

        if ($outputSchema) {
            $payload['output_config'] = [
                'format' => [
                    'type' => 'json_schema',
                    'schema' => $outputSchema,
                ],
            ];
        }

        $response = Http::timeout(30)
            ->withHeaders([
                'x-api-key' => $this->apiKey,
                'anthropic-version' => $this->apiVersion,
                'Content-Type' => 'application/json',
            ])
            ->post($this->endpoint, $payload);

        if ($response->failed()) {
            Log::error('Anthropic API error', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);

            throw new \RuntimeException(
                "Anthropic API error ({$response->status()}): {$response->body()}"
            );
        }

        $data = $response->json();
        $text = $data['content'][0]['text'] ?? null;

        if (!$text) {
            throw new \RuntimeException('Empty response from Anthropic API');
        }

        return [
            'text' => $text,
            'model' => $data['model'] ?? $model,
            'usage' => $data['usage'] ?? [],
        ];
    }

    public function correctGrammar(string $text, string $model = 'claude-haiku-4-5-20251001', string $userLanguage = 'fr'): array
    {
        $langInstruction = $userLanguage === 'fr'
            ? 'Redige toutes les explications en francais.'
            : 'Write all explanations in English.';

        $system = <<<PROMPT
Tu es un correcteur grammatical expert. Ta tache est de corriger les fautes de grammaire,
d'orthographe, de ponctuation et de syntaxe dans le texte fourni.

Regles :
- Corrige UNIQUEMENT les erreurs, ne reformule pas le style
- Preserve le ton et le registre de langue de l'utilisateur
- Preserve la mise en forme (retours a la ligne, etc.)
- Detecte automatiquement la langue du texte et corrige dans cette langue
- Si le texte est deja correct, retourne-le tel quel avec une liste errors vide
- Pour chaque erreur trouvee, indique le mot/passage original, la correction, et une explication pedagogique claire
- L'explication doit citer la regle de grammaire ou d'orthographe concernee
- {$langInstruction}
PROMPT;

        $schema = [
            'type' => 'object',
            'properties' => [
                'corrected' => [
                    'type' => 'string',
                    'description' => 'Le texte integralement corrige.',
                ],
                'explanation' => [
                    'type' => 'string',
                    'description' => 'Resume court des corrections apportees, ou "Aucune correction necessaire".',
                ],
                'errors' => [
                    'type' => 'array',
                    'description' => 'Liste detaillee de chaque erreur trouvee.',
                    'items' => [
                        'type' => 'object',
                        'properties' => [
                            'original' => [
                                'type' => 'string',
                                'description' => 'Le mot ou passage errone tel qu\'il apparait dans le texte original.',
                            ],
                            'correction' => [
                                'type' => 'string',
                                'description' => 'Le mot ou passage corrige.',
                            ],
                            'rule' => [
                                'type' => 'string',
                                'description' => 'Explication de la regle de grammaire, orthographe ou syntaxe violee. Sois pedagogique.',
                            ],
                        ],
                        'required' => ['original', 'correction', 'rule'],
                        'additionalProperties' => false,
                    ],
                ],
                'language' => [
                    'type' => 'string',
                    'description' => 'Code ISO 639-1 de la langue detectee (ex: fr, en, es).',
                ],
            ],
            'required' => ['corrected', 'explanation', 'errors', 'language'],
            'additionalProperties' => false,
        ];

        $response = $this->sendMessage($system, $text, $model, 4096, $schema);
        $parsed = json_decode($response['text'], true);

        if (!$parsed || !isset($parsed['corrected'])) {
            return [
                'corrected' => $response['text'],
                'explanation' => '',
                'errors' => [],
                'language' => 'unknown',
                'tokens_used' => $response['usage']['output_tokens'] ?? 0,
            ];
        }

        return [
            'corrected' => $parsed['corrected'],
            'explanation' => $parsed['explanation'] ?? '',
            'errors' => $parsed['errors'] ?? [],
            'language' => $parsed['language'] ?? 'unknown',
            'tokens_used' => ($response['usage']['input_tokens'] ?? 0) + ($response['usage']['output_tokens'] ?? 0),
        ];
    }

    public function translate(string $text, string $targetLanguage, string $model = 'claude-haiku-4-5-20251001', string $userLanguage = 'fr'): array
    {
        $languageNames = [
            'fr' => 'Francais', 'en' => 'English', 'es' => 'Espanol',
            'de' => 'Deutsch', 'it' => 'Italiano', 'pt' => 'Portugues',
            'nl' => 'Nederlands', 'ru' => 'Russkij', 'zh' => 'Zhongwen',
            'ja' => 'Nihongo', 'ko' => 'Hangugeo', 'ar' => 'Al-Arabiya',
            'pl' => 'Polski', 'tr' => 'Turkce', 'sv' => 'Svenska',
            'no' => 'Norsk', 'da' => 'Dansk', 'fi' => 'Suomi',
            'cs' => 'Cestina', 'ro' => 'Romana',
        ];

        $targetName = $languageNames[$targetLanguage] ?? $targetLanguage;

        $langInstruction = $userLanguage === 'fr'
            ? 'Redige les tips en francais pour un francophone qui apprend la langue cible.'
            : 'Write tips in English for an English speaker learning the target language.';

        $system = <<<PROMPT
Tu es un traducteur professionnel. Traduis le texte fourni vers {$targetName}.

Regles :
- Traduis de maniere naturelle et idiomatique, pas mot a mot
- Preserve le ton et le registre (formel, informel, technique, etc.)
- Preserve la mise en forme (retours a la ligne, etc.)
- Si le texte est deja dans la langue cible, retourne-le tel quel
- Ne traduis PAS les noms propres, marques, ou termes techniques reconnus
- Si tu reperes des points de grammaire ou vocabulaire interessants dans la traduction (faux-amis, expressions idiomatiques, regles specifiques de {$targetName}), ajoute-les en tips
- Les tips doivent etre pedagogiques et utiles pour un apprenant de {$targetName}
- Ne mets des tips que si c'est pertinent (expression idiomatique, faux-ami, regle de grammaire non evidente). Si la traduction est triviale, laisse le tableau tips vide.
- {$langInstruction}
PROMPT;

        $schema = [
            'type' => 'object',
            'properties' => [
                'translated' => [
                    'type' => 'string',
                    'description' => 'Le texte traduit dans la langue cible.',
                ],
                'source_language' => [
                    'type' => 'string',
                    'description' => 'Code ISO 639-1 de la langue source detectee (ex: fr, en, es).',
                ],
                'tips' => [
                    'type' => 'array',
                    'description' => 'Conseils pedagogiques sur la traduction : faux-amis, expressions idiomatiques, regles de grammaire specifiques a la langue cible. Peut etre vide si rien de notable.',
                    'items' => [
                        'type' => 'object',
                        'properties' => [
                            'term' => [
                                'type' => 'string',
                                'description' => 'Le mot ou expression concerne.',
                            ],
                            'tip' => [
                                'type' => 'string',
                                'description' => 'Explication pedagogique de la regle, du faux-ami ou de l\'expression idiomatique.',
                            ],
                        ],
                        'required' => ['term', 'tip'],
                        'additionalProperties' => false,
                    ],
                ],
            ],
            'required' => ['translated', 'source_language', 'tips'],
            'additionalProperties' => false,
        ];

        $response = $this->sendMessage($system, $text, $model, 4096, $schema);
        $parsed = json_decode($response['text'], true);

        if (!$parsed || !isset($parsed['translated'])) {
            return [
                'translated' => $response['text'],
                'source_language' => 'unknown',
                'tips' => [],
                'tokens_used' => $response['usage']['output_tokens'] ?? 0,
            ];
        }

        return [
            'translated' => $parsed['translated'],
            'source_language' => $parsed['source_language'] ?? 'unknown',
            'tips' => $parsed['tips'] ?? [],
            'tokens_used' => ($response['usage']['input_tokens'] ?? 0) + ($response['usage']['output_tokens'] ?? 0),
        ];
    }
}
