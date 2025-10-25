cp .env.deploy .env
composer dump-autoload --optimize
php artisan optimize:clear
php artisan migrate

# Permisos runtime
chown -R www-user:www-data storage bootstrap/cache || true

# Si falta rr.yaml, créalo ahora
if [ ! -f rr.yaml ] && [ ! -f .rr.yaml ] && [ ! -f .rr.yml ] && [ ! -f rr.yml ]; then
  echo "[INIT] Generating rr.yaml via octane:install..."
  php artisan octane:install --server=roadrunner --no-interaction
fi
exec php artisan octane:start --server=roadrunner --host=0.0.0.0 --port=8000
