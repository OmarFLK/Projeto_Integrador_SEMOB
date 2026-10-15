const transport = db.getSiblingDB('semob_data');
transport.createUser({
  user: 'semob',
  pwd: process.env.SEMOB_MONGO_APP_PASSWORD,
  roles: [{ role: 'readWrite', db: 'semob_data' }],
});
