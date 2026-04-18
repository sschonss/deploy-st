<?php
namespace Tests\Feature\Api;
use Tests\TestCase;

class StatusTest extends TestCase
{
    public function test_status_returns_environment_info(): void
    {
        $response = $this->getJson('/api/status');
        $response->assertStatus(200)->assertJsonStructure([
            'environment', 'debug', 'php_version', 'laravel_version',
        ]);
    }

    public function test_status_returns_correct_environment(): void
    {
        config(['app.env' => 'staging']);
        $response = $this->getJson('/api/status');
        $response->assertStatus(200)->assertJson(['environment' => 'staging']);
    }
}
