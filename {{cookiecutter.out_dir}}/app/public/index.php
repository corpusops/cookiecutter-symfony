<?php

use App\Kernel;
{%- if cookiecutter.symfony_ver in ["4.0", "4.1", "4.2","4.3"]  %}
use Symfony\Component\Debug\Debug;
{%- endif %}
use Symfony\Component\Dotenv\Dotenv;
{%- if not cookiecutter.symfony_ver in ["4.0", "4.1", "4.2","4.3"]  %}
use Symfony\Component\ErrorHandler\Debug;
{%- endif %}
use Symfony\Component\HttpFoundation\Request;

require dirname(__DIR__).'/vendor/autoload.php';

(new Dotenv())->load(__DIR__.'/../.env');
$env = $_SERVER['APP_ENV'] ?? $_ENV['APP_ENV'] ?? 'dev';
$debug = (bool)($_SERVER['APP_DEBUG'] ?? $_ENV['APP_DEBUG'] ?? ('prod' !== $env && 'preprod' !== $env && 'rec' !== $env));

if ($debug) {
    umask(0000);
    Debug::enable();
}

if ($trustedProxies = $_SERVER['TRUSTED_PROXIES'] ?? $_ENV['TRUSTED_PROXIES'] ?? false) {
    Request::setTrustedProxies(explode(',', $trustedProxies), Request::HEADER_X_FORWARDED_ALL ^ Request::HEADER_X_FORWARDED_HOST);
}

if ($trustedHosts = $_SERVER['TRUSTED_HOSTS'] ?? $_ENV['TRUSTED_HOSTS'] ?? false) {
    Request::setTrustedHosts(explode(',', $trustedHosts));
}

$kernel = new Kernel($env, $debug);
$request = Request::createFromGlobals();
$response = $kernel->handle($request);
$response->send();
$kernel->terminate($request, $response);
