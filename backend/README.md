# Backend (Django)

This backend is a Django-based API. It expects a PostgreSQL database.

Quick start

- Install Python dependencies:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

- Create a `.env` from the example and set your DB credentials (see `.env.example`).

```powershell
copy .env.example .env
# then edit .env to set DB_NAME, DB_USER, DB_PASSWORD, DB_HOST, DB_PORT
```

- Create PostgreSQL database and user (example commands for a Unix `psql` session):

```sql
-- as the postgres superuser
CREATE DATABASE api_db;
CREATE USER api_user WITH PASSWORD 'change_me';
GRANT ALL PRIVILEGES ON DATABASE api_db TO api_user;
```

Or using command line (Linux/macOS):

```bash
sudo -u postgres psql -c "CREATE DATABASE api_db;"
sudo -u postgres psql -c "CREATE USER api_user WITH PASSWORD 'change_me';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE api_db TO api_user;"
```

- Optional: import provided SQL dump (`waste_db.sql`) into the new DB:

```bash
psql -U api_user -d api_db -h localhost -f waste_db.sql
```

- Run migrations, create a superuser, and start the server:

```powershell
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver 0.0.0.0:8000
```

Notes
- Make sure the values in `.env` match your PostgreSQL instance and environment.
- If you prefer a single DATABASE_URL env var, configure it according to your project's settings modules.
- `waste_db.sql` is provided as an optional import; migrations are still recommended to set up the schema Django expects.

If you want, I can add a Docker Compose file to run PostgreSQL + the Django app together.
