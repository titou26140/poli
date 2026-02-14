# Poli Backend

Backend API pour l'application macOS Poli. Gere l'authentification, le proxy vers l'API Claude (Anthropic), les abonnements et l'historique.

## Stack technique

- **Framework** : Laravel 12 (PHP 8.2+)
- **Auth** : Laravel Sanctum (token-based)
- **Base de donnees** : SQLite (dev) / PostgreSQL (prod)
- **AI** : API Claude via Anthropic (deepset Haystack prevu pour les pipelines avances)

## Installation

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
```

### Configuration

Editer le fichier `.env` :

```env
# Cle API Anthropic (OBLIGATOIRE)
ANTHROPIC_API_KEY=sk-ant-xxx

# Base de donnees (SQLite par defaut)
DB_CONNECTION=sqlite
```

### Migrations

```bash
php artisan migrate
```

### Lancer le serveur

```bash
php artisan serve
# Accessible sur http://localhost:8000
```

## API Endpoints

### Authentification

| Methode | Route | Description | Auth |
|---------|-------|-------------|------|
| POST | `/api/auth/register` | Inscription | Non |
| POST | `/api/auth/login` | Connexion | Non |
| POST | `/api/auth/logout` | Deconnexion | Oui |
| GET | `/api/auth/me` | Profil utilisateur | Oui |

### Fonctionnalites principales

| Methode | Route | Description | Auth |
|---------|-------|-------------|------|
| POST | `/api/correct` | Correction grammaticale | Oui |
| POST | `/api/translate` | Traduction | Oui |
| GET | `/api/languages` | Langues disponibles | Oui |

### Historique

| Methode | Route | Description | Auth |
|---------|-------|-------------|------|
| GET | `/api/history` | Liste historique | Oui |
| PATCH | `/api/history/{type}/{id}/favorite` | Toggle favori | Oui |
| DELETE | `/api/history/{type}/{id}` | Supprimer | Oui |

### Abonnements

| Methode | Route | Description | Auth |
|---------|-------|-------------|------|
| GET | `/api/subscription/status` | Statut abonnement | Oui |
| POST | `/api/subscription/verify` | Verifier achat Apple | Oui |
| POST | `/api/subscription/cancel` | Annuler abonnement | Oui |

## Exemples d'utilisation

### Inscription
```bash
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"John","email":"john@example.com","password":"password123","password_confirmation":"password123"}'
```

### Correction
```bash
curl -X POST http://localhost:8000/api/correct \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"text":"Je suis alle au magasin hier et jai acheter du pain."}'
```

### Traduction
```bash
curl -X POST http://localhost:8000/api/translate \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello, how are you?","target_language":"fr"}'
```

## Modele economique

### Free tier
- 10 actions/jour (corrections + traductions)
- 4 langues : FR, EN, ES, DE
- Historique 7 jours
- Modele : Claude Haiku 4.5

### Pro tier
- Actions illimitees
- 20+ langues
- Historique illimite
- Modele : Claude Sonnet 4.5

## Haystack (Pipeline IA)

L'integration deepset Haystack est prevue pour les fonctionnalites avancees :
- Pipelines de traitement personnalises
- Reformulation avec choix de ton
- Analyse de style

Le microservice Haystack sera dans `haystack/` et communiquera avec Laravel via HTTP interne.

## Tests

```bash
php artisan test
```

## Deploiement

### Production
```bash
composer install --no-dev --optimize-autoloader
php artisan config:cache
php artisan route:cache
php artisan migrate --force
```
