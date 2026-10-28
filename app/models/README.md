# Models and migrations

The classes in this directory and in `nodeodm/models.py` define the database tables.

After changing a model generate the matching migration and commit it with the change:

```
docker compose exec webapp python manage.py makemigrations
```

The command writes a new numbered file under the app's `migrations/` directory.

Migrations are applied automatically by `start.sh` when the webapp container starts. Nothing needs to run `migrate` by hand.

Two branches that each add a migration with the same parent produce the error `Conflicting migrations detected; multiple leaf nodes`. Resolve it with:

```
docker compose exec webapp python manage.py makemigrations --merge
```
