<?php
namespace Tests\Feature\Api;
use Tests\TestCase;

class VersionTest extends TestCase
{
    public function test_version_returns_app_version(): void
    {
        config(['app.version' => '1.2.3']);
        $response = $this->getJson('/api/version');
        $response->assertStatus(200)->assertJson(['version' => '1.2.3']);
    }

    public function test_version_returns_app_name(): void
    {
        $response = $this->getJson('/api/version');
        $response->assertStatus(200)->assertJsonStructure(['version', 'app']);
    }
}
