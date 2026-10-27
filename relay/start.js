'use strict';

/*
 * Start the relay with the local `.env`, if present. The server itself still
 * reads only process.env, so tests and one-off `env KEY=... node relay/server.js`
 * runs behave exactly as before.
 */

require('./env').load();
require('./server').start();
