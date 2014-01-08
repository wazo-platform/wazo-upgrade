/*
 * XiVO Base-Config
 * Copyright (C) 2012-2014  Avencall
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

BEGIN;

TRUNCATE TABLE "stat_queue_periodic" CASCADE;

DROP TABLE IF EXISTS "stat_agent";
CREATE TABLE "stat_agent" (
 "id" SERIAL PRIMARY KEY,
 "name" VARCHAR(128) NOT NULL
);

GRANT ALL ON "stat_agent" TO asterisk;
GRANT ALL ON stat_agent_id_seq TO asterisk;

DROP TABLE IF EXISTS "stat_call_on_queue";
CREATE TABLE "stat_call_on_queue" (
 "id" SERIAL PRIMARY KEY,
 "callid" VARCHAR(32) NOT NULL,
 "time" timestamp NOT NULL,
 "ringtime" INTEGER NOT NULL DEFAULT 0,
 "talktime" INTEGER NOT NULL DEFAULT 0,
 "waittime" INTEGER NOT NULL DEFAULT 0,
 "status" call_exit_type NOT NULL,
 "queue_id" INTEGER REFERENCES stat_queue (id),
 "agent_id" INTEGER REFERENCES stat_agent (id)
);

GRANT ALL ON "stat_call_on_queue" TO asterisk;
GRANT ALL ON stat_call_on_queue_id_seq TO asterisk;

COMMIT;
