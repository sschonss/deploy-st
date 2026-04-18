# Deploy Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete, didactic deploy flow: Laravel API → Docker → GitHub Actions CI/CD → Helm Charts → ArgoCD on Minikube, with staging and production environments.

**Architecture:** Monorepo with Laravel API, multi-target Dockerfile (PHP-FPM + Nginx sidecar), Helm charts per environment, GitHub Actions for CI/CD, ArgoCD for GitOps delivery to Minikube namespaces.

**Tech Stack:** PHP 8.3, Laravel, Docker, Nginx, Helm, GitHub Actions, ArgoCD, Minikube, GHCR

---

## File Map

```
deploy-st/
├── app/                              # Laravel project root (created by composer)
│   ├── app/Http/Controllers/
│   │   └── Api/
│   │       ├── HealthController.php  # GET /api/health
│   │       ├── VersionController.php # GET /api/version
│   │       └── StatusController.php  # GET /api/status
│   ├── routes/api.php                # Modify: add 3 routes
│   ├── config/app.php                # Modify: add APP_VERSION
│   └── tests/Feature/Api/
│       ├── HealthTest.php
│       ├── VersionTest.php
│       └── StatusTest.php
├── docker/
│   ├── Dockerfile                    # Multi-target: app (PHP-FPM) + web (Nginx)
│   └── nginx.conf                    # Nginx reverse proxy config
├── helm/deploy-st/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-staging.yaml
│   ├── values-production.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       ├── configmap.yaml
│       ├── secret.yaml
│       ├── hpa.yaml
│       ├── pdb.yaml
│       └── _helpers.tpl
├── .github/workflows/
│   ├── ci.yml
│   └── cd.yml
├── argocd/
│   ├── staging-app.yaml
│   └── production-app.yaml
├── scripts/
│   ├── setup-minikube.sh
│   ├── install-argocd.sh
│   └── create-release.sh
├── .gitignore
└── README.md
```

---

## Task 1: Create Laravel Project

**Files:**
- Create: `app/` (entire Laravel project via `composer create-project`)
- Modify: `app/.env.example`

- [ ] **Step 1: Create Laravel project inside the `app/` directory**

```bash
cd /Users/luizschons/Documents/codes/deploy-st
composer create-project laravel/laravel app --no-interaction
```

Expected: Laravel project scaffolded in `app/`.

- [ ] **Step 2: Verify Laravel works**

```bash
cd /Users/luizschons/Documents/codes/deploy-st/app
php artisan --version
php artisan test
```

Expected: Laravel version printed, default tests pass.

- [ ] **Step 3: Clean up unused files for a minimal API**

Remove web routes and views we don't need (keep structure clean for didactic purposes):

```bash
cd /Users/luizschons/Documents/codes/deploy-st/app
rm -rf resources/views/welcome.blade.php
```

- [ ] **Step 4: Configure APP_VERSION in config/app.php**

Add a version config that reads from environment. Edit `app/config/app.php` — add this line after the `'name'` key:

```php
'version' => env('APP_VERSION', '0.0.0-dev'),
```

- [ ] **Step 5: Commit**

```bash
cd /Users/luizschons/Documents/codes/deploy-st
echo "app/vendor/" >> .gitignore
echo "app/node_modules/" >> .gitignore
echo "app/.env" >> .gitignore
git add .gitignore app/
git commit -m "feat: scaffold Laravel API project

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 2: API Endpoints — Health, Version, Status (TDD)

**Files:**
- Create: `app/app/Http/Controllers/Api/HealthController.php`
- Create: `app/app/Http/Controllers/Api/VersionController.php`
- Create: `app/app/Http/Controllers/Api/StatusController.php`
- Create: `app/tests/Feature/Api/HealthTest.php`
- Create: `app/tests/Feature/Api/VersionTest.php`
- Create: `app/tests/Feature/Api/StatusTest.php`
- Modify: `app/routes/api.php`

### Health Endpoint

- [ ] **Step 1: Write the failing test for /api/health**

Create `app/tests/Feature/Api/HealthTest.php`:

```php
<?php

namespace Tests\Feature\Api;

use Tests\TestCase;

class HealthTest extends TestCase
{
    public function test_health_returns_ok(): void
    {
        $response = $this->getJson('/api/health');

        $response->assertStatus(200)
            ->assertJson([
                'status' => 'ok',
            ]);
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/luizschons/Documents/codes/deploy-st/app
php artisan test --filter=HealthTest
```

Expected: FAIL (404, route not found).

- [ ] **Step 3: Create HealthController**

Create `app/app/Http/Controllers/Api/HealthController.php`:

```php
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;

class HealthController extends Controller
{
    public function __invoke(): JsonResponse
    {
        return response()->json(['status' => 'ok']);
    }
}
```

- [ ] **Step 4: Register the route**

Edit `app/routes/api.php` — replace contents with:

```php
<?php

use App\Http\Controllers\Api\HealthController;
use App\Http\Controllers\Api\VersionController;
use App\Http\Controllers\Api\StatusController;
use Illuminate\Support\Facades\Route;

Route::get('/health', HealthController::class);
Route::get('/version', VersionController::class);
Route::get('/status', StatusController::class);
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd /Users/luizschons/Documents/codes/deploy-st/app
php artisan test --filter=HealthTest
```

Expected: PASS.

### Version Endpoint

- [ ] **Step 6: Write the failing test for /api/version**

Create `app/tests/Feature/Api/VersionTest.php`:

```php
<?php

namespace Tests\Feature\Api;

use Tests\TestCase;

class VersionTest extends TestCase
{
    public function test_version_returns_app_version(): void
    {
        config(['app.version' => '1.2.3']);

        $response = $this->getJson('/api/version');

        $response->assertStatus(200)
            ->assertJson([
                'version' => '1.2.3',
            ]);
    }

    public function test_version_returns_app_name(): void
    {
        $response = $this->getJson('/api/version');

        $response->assertStatus(200)
            ->assertJsonStructure(['version', 'app']);
    }
}
```

- [ ] **Step 7: Run test to verify it fails**

```bash
cd /Users/luizschons/Documents/codes/deploy-st/app
php artisan test --filter=VersionTest
```

Expected: FAIL (controller not found, 500 error).

- [ ] **Step 8: Create VersionController**

Create `app/app/Http/Controllers/Api/VersionController.php`:

```php
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;

class VersionController extends Controller
{
    public function __invoke(): JsonResponse
    {
        return response()->json([
            'version' => config('app.version'),
            'app' => config('app.name'),
        ]);
    }
}
```

- [ ] **Step 9: Run test to verify it passes**

```bash
cd /Users/luizschons/Documents/codes/deploy-st/app
php artisan test --filter=VersionTest
```

Expected: PASS.

### Status Endpoint

- [ ] **Step 10: Write the failing test for /api/status**

Create `app/tests/Feature/Api/StatusTest.php`:

```php
<?php

namespace Tests\Feature\Api;

use Tests\TestCase;

class StatusTest extends TestCase
{
    public function test_status_returns_environment_info(): void
    {
        $response = $this->getJson('/api/status');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'environment',
                'debug',
                'php_version',
                'laravel_version',
            ]);
    }

    public function test_status_returns_correct_environment(): void
    {
        config(['app.env' => 'staging']);

        $response = $this->getJson('/api/status');

        $response->assertStatus(200)
            ->assertJson([
                'environment' => 'staging',
            ]);
    }
}
```

- [ ] **Step 11: Run test to verify it fails**

```bash
cd /Users/luizschons/Documents/codes/deploy-st/app
php artisan test --filter=StatusTest
```

Expected: FAIL.

- [ ] **Step 12: Create StatusController**

Create `app/app/Http/Controllers/Api/StatusController.php`:

```php
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Foundation\Application;
use Illuminate\Http\JsonResponse;

class StatusController extends Controller
{
    public function __invoke(): JsonResponse
    {
        return response()->json([
            'environment' => config('app.env'),
            'debug' => config('app.debug'),
            'php_version' => PHP_VERSION,
            'laravel_version' => Application::VERSION,
        ]);
    }
}
```

- [ ] **Step 13: Run all API tests**

```bash
cd /Users/luizschons/Documents/codes/deploy-st/app
php artisan test --filter=Api
```

Expected: All 5 tests PASS.

- [ ] **Step 14: Commit**

```bash
cd /Users/luizschons/Documents/codes/deploy-st
git add app/app/Http/Controllers/Api/ app/tests/Feature/Api/ app/routes/api.php app/config/app.php
git commit -m "feat: add health, version, status API endpoints with tests

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 3: Docker — Multi-Target Build

**Files:**
- Create: `docker/Dockerfile`
- Create: `docker/nginx.conf`
- Create: `.dockerignore`

- [ ] **Step 1: Create nginx.conf**

Create `docker/nginx.conf`:

```nginx
server {
    listen 80;
    server_name _;
    root /var/www/html/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

- [ ] **Step 2: Create multi-target Dockerfile**

Create `docker/Dockerfile`:

```dockerfile
# ==============================================================================
# Stage 1: Composer dependencies
# ==============================================================================
FROM composer:2 AS composer-deps

WORKDIR /build
COPY app/composer.json app/composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist

COPY app/ .
RUN composer dump-autoload --optimize --no-dev

# ==============================================================================
# Target: app (PHP-FPM)
# Serves Laravel via PHP-FPM on port 9000
# ==============================================================================
FROM php:8.3-fpm-alpine AS app

RUN apk add --no-cache \
    libzip-dev \
    && docker-php-ext-install zip opcache

# PHP production config
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

WORKDIR /var/www/html

COPY --from=composer-deps /build /var/www/html

RUN chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

USER www-data

EXPOSE 9000

# ==============================================================================
# Target: web (Nginx)
# Reverse proxy to PHP-FPM, serves static assets
# ==============================================================================
FROM nginx:1.25-alpine AS web

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=composer-deps /build/public /var/www/html/public

EXPOSE 80
```

- [ ] **Step 3: Create .dockerignore**

Create `.dockerignore` in the repo root:

```
app/vendor/
app/node_modules/
app/.env
app/storage/logs/*
app/storage/framework/cache/*
app/storage/framework/sessions/*
app/storage/framework/views/*
.git/
docs/
helm/
argocd/
scripts/
.github/
```

- [ ] **Step 4: Test Docker build locally**

```bash
cd /Users/luizschons/Documents/codes/deploy-st
docker build -f docker/Dockerfile --target app -t deploy-st-app:test .
docker build -f docker/Dockerfile --target web -t deploy-st-web:test .
```

Expected: Both images build successfully.

- [ ] **Step 5: Verify the app image works**

```bash
docker run --rm deploy-st-app:test php artisan --version
```

Expected: Prints Laravel version.

- [ ] **Step 6: Clean up test images**

```bash
docker rmi deploy-st-app:test deploy-st-web:test 2>/dev/null || true
```

- [ ] **Step 7: Commit**

```bash
cd /Users/luizschons/Documents/codes/deploy-st
git add docker/ .dockerignore
git commit -m "feat: add multi-target Dockerfile (PHP-FPM + Nginx)

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 4: Helm Chart

**Files:**
- Create: `helm/deploy-st/Chart.yaml`
- Create: `helm/deploy-st/values.yaml`
- Create: `helm/deploy-st/values-staging.yaml`
- Create: `helm/deploy-st/values-production.yaml`
- Create: `helm/deploy-st/templates/_helpers.tpl`
- Create: `helm/deploy-st/templates/deployment.yaml`
- Create: `helm/deploy-st/templates/service.yaml`
- Create: `helm/deploy-st/templates/ingress.yaml`
- Create: `helm/deploy-st/templates/configmap.yaml`
- Create: `helm/deploy-st/templates/secret.yaml`
- Create: `helm/deploy-st/templates/hpa.yaml`
- Create: `helm/deploy-st/templates/pdb.yaml`

- [ ] **Step 1: Create Chart.yaml**

Create `helm/deploy-st/Chart.yaml`:

```yaml
apiVersion: v2
name: deploy-st
description: Laravel API deploy flow — didactic Helm chart
type: application
version: 0.1.0
appVersion: "0.0.0-dev"
```

- [ ] **Step 2: Create _helpers.tpl**

Create `helm/deploy-st/templates/_helpers.tpl`:

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "deploy-st.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "deploy-st.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "deploy-st.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "deploy-st.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "deploy-st.selectorLabels" -}}
app.kubernetes.io/name: {{ include "deploy-st.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

- [ ] **Step 3: Create values.yaml (defaults)**

Create `helm/deploy-st/values.yaml`:

```yaml
replicaCount: 1

image:
  app:
    repository: ghcr.io/sschonss/deploy-st-app
    tag: "latest"
    pullPolicy: IfNotPresent
  web:
    repository: ghcr.io/sschonss/deploy-st-web
    tag: "latest"
    pullPolicy: IfNotPresent

nameOverride: ""
fullnameOverride: ""

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  className: nginx
  host: deploy-st.local

resources:
  app:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 250m
      memory: 256Mi
  web:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 128Mi

hpa:
  enabled: false
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70

pdb:
  enabled: false
  minAvailable: 1

env:
  APP_NAME: "deploy-st"
  APP_ENV: "production"
  APP_DEBUG: "false"
  APP_VERSION: "0.0.0-dev"
  LOG_CHANNEL: "stderr"
  LOG_LEVEL: "warning"

secrets:
  APP_KEY: "base64:dummyKeyForStudyPurposesOnly1234="
```

- [ ] **Step 4: Create values-staging.yaml**

Create `helm/deploy-st/values-staging.yaml`:

```yaml
replicaCount: 1

image:
  app:
    tag: "latest"
  web:
    tag: "latest"

ingress:
  host: staging.deploy-st.local

resources:
  app:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 250m
      memory: 256Mi
  web:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 128Mi

hpa:
  enabled: false

pdb:
  enabled: false

env:
  APP_ENV: "staging"
  APP_DEBUG: "true"
  LOG_LEVEL: "debug"
```

- [ ] **Step 5: Create values-production.yaml**

Create `helm/deploy-st/values-production.yaml`:

```yaml
replicaCount: 2

image:
  app:
    tag: "v0.1.0"
  web:
    tag: "v0.1.0"

ingress:
  host: production.deploy-st.local

resources:
  app:
    requests:
      cpu: 250m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
  web:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi

hpa:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70

pdb:
  enabled: true
  minAvailable: 1

env:
  APP_ENV: "production"
  APP_DEBUG: "false"
  LOG_LEVEL: "warning"
```

- [ ] **Step 6: Create deployment.yaml template**

Create `helm/deploy-st/templates/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "deploy-st.fullname" . }}
  labels:
    {{- include "deploy-st.labels" . | nindent 4 }}
spec:
  {{- if not .Values.hpa.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "deploy-st.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "deploy-st.selectorLabels" . | nindent 8 }}
    spec:
      containers:
        # PHP-FPM container
        - name: app
          image: "{{ .Values.image.app.repository }}:{{ .Values.image.app.tag }}"
          imagePullPolicy: {{ .Values.image.app.pullPolicy }}
          ports:
            - name: php-fpm
              containerPort: 9000
              protocol: TCP
          envFrom:
            - configMapRef:
                name: {{ include "deploy-st.fullname" . }}
            - secretRef:
                name: {{ include "deploy-st.fullname" . }}
          livenessProbe:
            exec:
              command:
                - php-fpm-healthcheck
            initialDelaySeconds: 10
            periodSeconds: 10
          readinessProbe:
            exec:
              command:
                - php-fpm-healthcheck
            initialDelaySeconds: 5
            periodSeconds: 5
          resources:
            {{- toYaml .Values.resources.app | nindent 12 }}

        # Nginx container (sidecar)
        - name: web
          image: "{{ .Values.image.web.repository }}:{{ .Values.image.web.tag }}"
          imagePullPolicy: {{ .Values.image.web.pullPolicy }}
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /api/health
              port: http
            initialDelaySeconds: 15
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /api/health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 5
          startupProbe:
            httpGet:
              path: /api/health
              port: http
            initialDelaySeconds: 10
            failureThreshold: 30
            periodSeconds: 5
          resources:
            {{- toYaml .Values.resources.web | nindent 12 }}
```

- [ ] **Step 7: Create service.yaml template**

Create `helm/deploy-st/templates/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "deploy-st.fullname" . }}
  labels:
    {{- include "deploy-st.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "deploy-st.selectorLabels" . | nindent 4 }}
```

- [ ] **Step 8: Create ingress.yaml template**

Create `helm/deploy-st/templates/ingress.yaml`:

```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "deploy-st.fullname" . }}
  labels:
    {{- include "deploy-st.labels" . | nindent 4 }}
spec:
  ingressClassName: {{ .Values.ingress.className }}
  rules:
    - host: {{ .Values.ingress.host }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ include "deploy-st.fullname" . }}
                port:
                  number: {{ .Values.service.port }}
{{- end }}
```

- [ ] **Step 9: Create configmap.yaml template**

Create `helm/deploy-st/templates/configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "deploy-st.fullname" . }}
  labels:
    {{- include "deploy-st.labels" . | nindent 4 }}
data:
  {{- range $key, $value := .Values.env }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
```

- [ ] **Step 10: Create secret.yaml template**

Create `helm/deploy-st/templates/secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "deploy-st.fullname" . }}
  labels:
    {{- include "deploy-st.labels" . | nindent 4 }}
type: Opaque
stringData:
  {{- range $key, $value := .Values.secrets }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
```

- [ ] **Step 11: Create hpa.yaml template**

Create `helm/deploy-st/templates/hpa.yaml`:

```yaml
{{- if .Values.hpa.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "deploy-st.fullname" . }}
  labels:
    {{- include "deploy-st.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "deploy-st.fullname" . }}
  minReplicas: {{ .Values.hpa.minReplicas }}
  maxReplicas: {{ .Values.hpa.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.hpa.targetCPUUtilizationPercentage }}
{{- end }}
```

- [ ] **Step 12: Create pdb.yaml template**

Create `helm/deploy-st/templates/pdb.yaml`:

```yaml
{{- if .Values.pdb.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "deploy-st.fullname" . }}
  labels:
    {{- include "deploy-st.labels" . | nindent 4 }}
spec:
  minAvailable: {{ .Values.pdb.minAvailable }}
  selector:
    matchLabels:
      {{- include "deploy-st.selectorLabels" . | nindent 6 }}
{{- end }}
```

- [ ] **Step 13: Validate Helm chart (template render)**

```bash
cd /Users/luizschons/Documents/codes/deploy-st
helm template test-release helm/deploy-st -f helm/deploy-st/values-staging.yaml
```

Expected: Renders YAML manifests without errors. HPA and PDB should NOT appear (disabled in staging).

```bash
helm template test-release helm/deploy-st -f helm/deploy-st/values-production.yaml
```

Expected: Renders with HPA and PDB included (enabled in production).

- [ ] **Step 14: Commit**

```bash
cd /Users/luizschons/Documents/codes/deploy-st
git add helm/
git commit -m "feat: add Helm chart with per-environment values

Includes deployment, service, ingress, configmap, secret, HPA, PDB.
Staging: 1 replica, debug on, no HPA.
Production: 2 replicas, HPA 2-5, PDB minAvailable=1.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 5: GitHub Actions — CI Pipeline

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Create CI workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: ["*"]
  pull_request:
    branches: [main]

jobs:
  test:
    name: Tests
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: app

    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: "8.3"
          extensions: zip
          coverage: none

      - name: Cache Composer dependencies
        uses: actions/cache@v4
        with:
          path: app/vendor
          key: composer-${{ hashFiles('app/composer.lock') }}
          restore-keys: composer-

      - name: Install dependencies
        run: composer install --no-interaction --prefer-dist --optimize-autoloader

      - name: Copy environment file
        run: cp .env.example .env

      - name: Generate app key
        run: php artisan key:generate

      - name: Run tests
        run: php artisan test

  docker-build:
    name: Docker Build Validation
    runs-on: ubuntu-latest
    needs: test

    steps:
      - uses: actions/checkout@v4

      - name: Build app image
        run: docker build -f docker/Dockerfile --target app -t deploy-st-app:ci .

      - name: Build web image
        run: docker build -f docker/Dockerfile --target web -t deploy-st-web:ci .

      - name: Verify app image
        run: docker run --rm deploy-st-app:ci php artisan --version
```

- [ ] **Step 2: Commit**

```bash
cd /Users/luizschons/Documents/codes/deploy-st
mkdir -p .github/workflows
git add .github/workflows/ci.yml
git commit -m "ci: add CI pipeline — tests + Docker build validation

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 6: GitHub Actions — CD Pipeline

**Files:**
- Create: `.github/workflows/cd.yml`

- [ ] **Step 1: Create CD workflow**

Create `.github/workflows/cd.yml`:

```yaml
name: CD

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write
  packages: write

jobs:
  release:
    name: Build, Push & Release
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Extract version from tag
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/}" >> "$GITHUB_OUTPUT"

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push app image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: docker/Dockerfile
          target: app
          push: true
          tags: |
            ghcr.io/${{ github.repository }}-app:${{ steps.version.outputs.VERSION }}
            ghcr.io/${{ github.repository }}-app:latest

      - name: Build and push web image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: docker/Dockerfile
          target: web
          push: true
          tags: |
            ghcr.io/${{ github.repository }}-web:${{ steps.version.outputs.VERSION }}
            ghcr.io/${{ github.repository }}-web:latest

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
          body: |
            ## Docker Images

            ```bash
            docker pull ghcr.io/${{ github.repository }}-app:${{ steps.version.outputs.VERSION }}
            docker pull ghcr.io/${{ github.repository }}-web:${{ steps.version.outputs.VERSION }}
            ```

  update-staging:
    name: Update Staging Values
    runs-on: ubuntu-latest
    needs: release

    steps:
      - uses: actions/checkout@v4
        with:
          ref: main
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract version from tag
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/}" >> "$GITHUB_OUTPUT"

      - name: Update staging image tags
        run: |
          cd helm/deploy-st
          sed -i "s/tag: \".*\"/tag: \"${{ steps.version.outputs.VERSION }}\"/" values-staging.yaml

      - name: Commit and push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add helm/deploy-st/values-staging.yaml
          git commit -m "chore: update staging to ${{ steps.version.outputs.VERSION }}"
          git push
```

- [ ] **Step 2: Commit**

```bash
cd /Users/luizschons/Documents/codes/deploy-st
git add .github/workflows/cd.yml
git commit -m "ci: add CD pipeline — build, push GHCR, release, update staging

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 7: ArgoCD Application Manifests

**Files:**
- Create: `argocd/staging-app.yaml`
- Create: `argocd/production-app.yaml`

- [ ] **Step 1: Create staging ArgoCD Application**

Create `argocd/staging-app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: deploy-st-staging
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/sschonss/deploy-st.git
    targetRevision: main
    path: helm/deploy-st
    helm:
      valueFiles:
        - values-staging.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: staging
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

- [ ] **Step 2: Create production ArgoCD Application**

Create `argocd/production-app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: deploy-st-production
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/sschonss/deploy-st.git
    targetRevision: main
    path: helm/deploy-st
    helm:
      valueFiles:
        - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
    # No automated sync — production requires manual sync via ArgoCD UI
```

- [ ] **Step 3: Commit**

```bash
cd /Users/luizschons/Documents/codes/deploy-st
git add argocd/
git commit -m "feat: add ArgoCD application manifests (staging + production)

Staging: auto-sync with prune and self-heal.
Production: manual sync only.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 8: Setup Scripts

**Files:**
- Create: `scripts/setup-minikube.sh`
- Create: `scripts/install-argocd.sh`
- Create: `scripts/create-release.sh`

- [ ] **Step 1: Create setup-minikube.sh**

Create `scripts/setup-minikube.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Deploy ST — Minikube Setup ==="
echo ""

# Start Minikube
if minikube status | grep -q "Running"; then
    echo "✅ Minikube is already running"
else
    echo "🚀 Starting Minikube..."
    minikube start --driver=docker --cpus=2 --memory=4096
fi

# Enable addons
echo ""
echo "📦 Enabling addons..."
minikube addons enable ingress
minikube addons enable metrics-server

# Create namespaces
echo ""
echo "📁 Creating namespaces..."
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Show status
echo ""
echo "=== Setup Complete ==="
echo ""
echo "Cluster:     $(kubectl cluster-info | head -1)"
echo "Namespaces:  staging, production, argocd"
echo ""
echo "Next step: ./scripts/install-argocd.sh"
```

- [ ] **Step 2: Create install-argocd.sh**

Create `scripts/install-argocd.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Deploy ST — ArgoCD Installation ==="
echo ""

# Install ArgoCD
echo "📦 Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo ""
echo "⏳ Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# Get initial admin password
echo ""
echo "🔑 ArgoCD admin password:"
ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "   Username: admin"
echo "   Password: $ARGO_PWD"

# Apply ArgoCD Applications
echo ""
echo "📋 Applying ArgoCD Applications..."
kubectl apply -f argocd/staging-app.yaml
kubectl apply -f argocd/production-app.yaml

echo ""
echo "=== ArgoCD Installation Complete ==="
echo ""
echo "To access the ArgoCD dashboard, run:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "Then open: https://localhost:8080"
echo "  Username: admin"
echo "  Password: $ARGO_PWD"
```

- [ ] **Step 3: Create create-release.sh**

Create `scripts/create-release.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: ./scripts/create-release.sh <version>"
    echo "Example: ./scripts/create-release.sh 1.0.0"
    exit 1
fi

VERSION="$1"
TAG="v${VERSION}"

echo "=== Creating Release ${TAG} ==="
echo ""

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "❌ Error: You have uncommitted changes. Commit or stash them first."
    exit 1
fi

# Check if tag already exists
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "❌ Error: Tag $TAG already exists."
    exit 1
fi

# Create and push tag
echo "🏷️  Creating tag $TAG..."
git tag -a "$TAG" -m "Release $TAG"

echo "🚀 Pushing tag to origin..."
git push origin "$TAG"

echo ""
echo "=== Release $TAG Created ==="
echo ""
echo "The CD pipeline will now:"
echo "  1. Build Docker images"
echo "  2. Push to ghcr.io"
echo "  3. Create GitHub Release"
echo "  4. Update staging values"
echo ""
echo "Monitor: https://github.com/sschonss/deploy-st/actions"
```

- [ ] **Step 4: Make scripts executable**

```bash
cd /Users/luizschons/Documents/codes/deploy-st
chmod +x scripts/setup-minikube.sh scripts/install-argocd.sh scripts/create-release.sh
```

- [ ] **Step 5: Commit**

```bash
cd /Users/luizschons/Documents/codes/deploy-st
git add scripts/
git commit -m "feat: add setup scripts (minikube, argocd, release helper)

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 9: README — Didactic Guide

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create README.md**

Create `README.md`:

````markdown
# Deploy ST — Fluxo Completo de Deploy

> Projeto didático: Laravel API → Docker → GitHub Actions → Helm → ArgoCD → Kubernetes

Este repositório demonstra um fluxo completo de deploy, do código ao cluster Kubernetes, usando ferramentas padrão da indústria.

## Arquitetura

```
┌──────────┐     ┌────────────────┐     ┌──────────┐     ┌─────────────┐
│Developer │────▶│ GitHub Actions │────▶│  GHCR    │────▶│  ArgoCD     │
│ git push │     │  CI/CD         │     │ (images) │     │  (GitOps)   │
└──────────┘     └────────────────┘     └──────────┘     └──────┬──────┘
                                                                │
                                                    ┌───────────┴───────────┐
                                                    │                       │
                                              ┌─────▼─────┐         ┌──────▼──────┐
                                              │  Staging   │         │ Production  │
                                              │ (auto-sync)│         │(manual sync)│
                                              └───────────┘         └─────────────┘
```

## Pré-requisitos

| Ferramenta | Versão mínima | Instalação |
|------------|---------------|------------|
| Docker | 20+ | [docker.com](https://docs.docker.com/get-docker/) |
| Minikube | 1.30+ | `brew install minikube` |
| kubectl | 1.27+ | `brew install kubectl` |
| Helm | 3.12+ | `brew install helm` |
| PHP | 8.3+ | `brew install php` |
| Composer | 2.5+ | `brew install composer` |
| GitHub CLI | 2.0+ | `brew install gh` |

## Setup Rápido

### 1. Clone o repositório

```bash
git clone https://github.com/sschonss/deploy-st.git
cd deploy-st
```

### 2. Instale as dependências do Laravel

```bash
cd app
composer install
cp .env.example .env
php artisan key:generate
cd ..
```

### 3. Rode os testes localmente

```bash
cd app && php artisan test && cd ..
```

### 4. Suba o Minikube

```bash
./scripts/setup-minikube.sh
```

### 5. Instale o ArgoCD

```bash
./scripts/install-argocd.sh
```

### 6. Configure o /etc/hosts

```bash
MINIKUBE_IP=$(minikube ip)
echo "$MINIKUBE_IP staging.deploy-st.local" | sudo tee -a /etc/hosts
echo "$MINIKUBE_IP production.deploy-st.local" | sudo tee -a /etc/hosts
```

### 7. Acesse o ArgoCD

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Abra: https://localhost:8080
# User: admin | Senha: exibida no install-argocd.sh
```

## Entendendo o Fluxo

### CI (Integração Contínua)

Todo push e pull request dispara o pipeline CI:

1. **Testes:** `php artisan test` roda os testes do Laravel
2. **Build Docker:** Valida que as imagens Docker compilam sem erros

Veja: [`.github/workflows/ci.yml`](.github/workflows/ci.yml)

### CD (Entrega Contínua)

Criar uma tag `v*` dispara o pipeline CD:

1. **Build:** Compila imagens Docker (`app` + `web`)
2. **Push:** Publica no GitHub Container Registry (GHCR)
3. **Release:** Cria GitHub Release com changelog automático
4. **Update:** Atualiza `values-staging.yaml` com a nova versão

Veja: [`.github/workflows/cd.yml`](.github/workflows/cd.yml)

### GitOps com ArgoCD

O ArgoCD monitora este repositório e sincroniza com o cluster:

- **Staging:** Auto-sync — qualquer mudança no Helm chart é aplicada automaticamente
- **Production:** Manual sync — requer aprovação explícita no dashboard do ArgoCD

## Fazendo sua Primeira Release

```bash
# 1. Certifique-se que está na main com tudo commitado
git checkout main
git pull

# 2. Crie a release
./scripts/create-release.sh 1.0.0

# 3. Acompanhe o pipeline
# https://github.com/sschonss/deploy-st/actions

# 4. Verifique o staging
curl http://staging.deploy-st.local/api/version
# {"version":"v1.0.0","app":"deploy-st"}

# 5. Promova para production
# Abra o ArgoCD → deploy-st-production → Sync
```

## Verificando o Deploy

```bash
# Health check
curl http://staging.deploy-st.local/api/health
# {"status":"ok"}

# Versão
curl http://staging.deploy-st.local/api/version
# {"version":"v1.0.0","app":"deploy-st"}

# Info do ambiente
curl http://staging.deploy-st.local/api/status
# {"environment":"staging","debug":true,...}
```

## Estrutura do Projeto

```
deploy-st/
├── app/               # Laravel API (health, version, status)
├── docker/            # Dockerfile multi-target + nginx.conf
├── helm/deploy-st/    # Helm chart (values por ambiente)
├── .github/workflows/ # CI + CD pipelines
├── argocd/            # ArgoCD Application manifests
└── scripts/           # Setup helpers (minikube, argocd, release)
```

## Troubleshooting

**Minikube não inicia:**
```bash
minikube delete && minikube start --driver=docker
```

**Pods em CrashLoopBackOff:**
```bash
kubectl logs -n staging deploy/deploy-st-staging --container app
kubectl logs -n staging deploy/deploy-st-staging --container web
```

**ArgoCD não sincroniza:**
```bash
# Verifique o status da Application
kubectl get applications -n argocd
# Force sync
kubectl -n argocd patch application deploy-st-staging --type merge -p '{"operation":{"sync":{}}}'
```

**Ingress não funciona:**
```bash
# Verifique se o addon está habilitado
minikube addons list | grep ingress
# Verifique o /etc/hosts
cat /etc/hosts | grep deploy-st
```
````

- [ ] **Step 2: Commit**

```bash
cd /Users/luizschons/Documents/codes/deploy-st
git add README.md
git commit -m "docs: add didactic README with step-by-step guide

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 10: Local GitHub Actions with `act`

**Files:**
- Create: `scripts/run-ci-local.sh`
- Create: `.actrc`

- [ ] **Step 1: Install act**

```bash
brew install act
```

- [ ] **Step 2: Create .actrc config**

Create `.actrc` in the repo root:

```
-P ubuntu-latest=catthehacker/ubuntu:act-latest
```

This tells `act` which Docker image to use for `ubuntu-latest` runners.

- [ ] **Step 3: Create run-ci-local.sh helper**

Create `scripts/run-ci-local.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Running GitHub Actions Locally with act ==="
echo ""

if ! command -v act &> /dev/null; then
    echo "❌ 'act' is not installed. Install with: brew install act"
    exit 1
fi

WORKFLOW="${1:-ci}"

case "$WORKFLOW" in
    ci)
        echo "🧪 Running CI pipeline (tests + Docker build)..."
        act push -W .github/workflows/ci.yml --container-architecture linux/amd64
        ;;
    cd)
        VERSION="${2:-v0.0.1-test}"
        echo "🚀 Simulating CD pipeline for tag $VERSION..."
        act push -W .github/workflows/cd.yml --container-architecture linux/amd64 \
            -e <(echo "{\"ref\": \"refs/tags/$VERSION\", \"ref_name\": \"$VERSION\"}")
        ;;
    *)
        echo "Usage: ./scripts/run-ci-local.sh [ci|cd] [version]"
        echo ""
        echo "Examples:"
        echo "  ./scripts/run-ci-local.sh ci           # Run CI pipeline"
        echo "  ./scripts/run-ci-local.sh cd v1.0.0    # Simulate CD for v1.0.0"
        exit 1
        ;;
esac

echo ""
echo "=== Done ==="
```

- [ ] **Step 4: Make script executable**

```bash
chmod +x scripts/run-ci-local.sh
```

- [ ] **Step 5: Test CI pipeline locally**

```bash
cd /Users/luizschons/Documents/codes/deploy-st
./scripts/run-ci-local.sh ci
```

Expected: `act` pulls Docker image, runs test job and docker-build job. All pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/luizschons/Documents/codes/deploy-st
git add .actrc scripts/run-ci-local.sh
git commit -m "feat: add local GitHub Actions runner with act

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 11: Push to GitHub

**Files:** None (repo operations)

- [ ] **Step 1: Rename branch to main**

```bash
cd /Users/luizschons/Documents/codes/deploy-st
git branch -M main
```

- [ ] **Step 2: Create GitHub repository**

```bash
gh repo create sschonss/deploy-st --public --source=. --description "Fluxo completo de deploy: Laravel + Docker + GitHub Actions + Helm + ArgoCD + Minikube"
```

- [ ] **Step 3: Push all code**

```bash
git push -u origin main
```

- [ ] **Step 4: Verify on GitHub**

```bash
gh repo view sschonss/deploy-st --web
```

Expected: Repository visible with all files and README rendered.
