<?php
use App\Http\Controllers\Api\HealthController;
use App\Http\Controllers\Api\VersionController;
use App\Http\Controllers\Api\StatusController;
use Illuminate\Support\Facades\Route;

Route::get('/health', HealthController::class);
Route::get('/version', VersionController::class);
Route::get('/status', StatusController::class);
