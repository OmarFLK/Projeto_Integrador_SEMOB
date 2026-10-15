/// Append new versions; never modify an applied migration.
const identityMigrations = <int, List<String>>{
  1: [
    '''CREATE TABLE users(
      id TEXT PRIMARY KEY, email TEXT NOT NULL, identifier TEXT UNIQUE,
      name TEXT NOT NULL, job_title TEXT NOT NULL DEFAULT '', department TEXT NOT NULL DEFAULT '',
      role TEXT NOT NULL CHECK(role IN ('administrator','manager','analyst','operator')),
      active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)), password_hash TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL, last_access TIMESTAMPTZ)''',
    'CREATE UNIQUE INDEX users_email_unique ON users(lower(email))',
    '''CREATE TABLE sessions(token_hash TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id), expires_at TIMESTAMPTZ NOT NULL)''',
    'CREATE INDEX sessions_user ON sessions(user_id)',
    'CREATE INDEX sessions_expiry ON sessions(expires_at)',
    '''CREATE TABLE recovery(id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id),
      code_hash TEXT NOT NULL, expires_at TIMESTAMPTZ NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0 CHECK(attempts>=0), reset_hash TEXT,
      verified INTEGER NOT NULL DEFAULT 0 CHECK(verified IN (0,1)),
      consumed INTEGER NOT NULL DEFAULT 0 CHECK(consumed IN (0,1)))''',
    'CREATE INDEX recovery_user ON recovery(user_id)',
    'CREATE TABLE preferences(user_id TEXT PRIMARY KEY REFERENCES users(id), json TEXT NOT NULL)',
    '''CREATE TABLE audit(id BIGSERIAL PRIMARY KEY, user_id TEXT, action TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL, details TEXT NOT NULL)''',
    '''CREATE TABLE identity_imports(source_hash TEXT PRIMARY KEY,
      imported_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, counts TEXT NOT NULL)''',
  ],
};

/// Whitelist shared by SQLite migration and logical backup/restore.
const identityColumns = <String, List<String>>{
  'users': [
    'id',
    'email',
    'identifier',
    'name',
    'job_title',
    'department',
    'role',
    'active',
    'password_hash',
    'created_at',
    'last_access',
  ],
  'sessions': ['token_hash', 'user_id', 'expires_at'],
  'recovery': [
    'id',
    'user_id',
    'code_hash',
    'expires_at',
    'attempts',
    'reset_hash',
    'verified',
    'consumed',
  ],
  'preferences': ['user_id', 'json'],
  'audit': ['id', 'user_id', 'action', 'created_at', 'details'],
};
