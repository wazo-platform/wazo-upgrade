/*
 * Copyright (C) 2013  Avencall
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

ALTER TABLE dialaction 
    DROP CONSTRAINT IF EXISTS dialaction_pkey;

DROP INDEX IF EXISTS phonefunckey__idx__typeextenumbersright_typevalextenumbersright;

ALTER TABLE agentfeatures 
    ALTER COLUMN "group" SET DEFAULT NULL::character varying;

ALTER TABLE cel
    ALTER COLUMN appdata TYPE character varying(80) /* TYPE change - table: cel original: character varying(512) new: character varying(80) */;

ALTER TABLE dialaction
    ALTER COLUMN actionarg1 SET DEFAULT NULL::character varying,
    ALTER COLUMN actionarg2 SET DEFAULT NULL::character varying,
    ALTER COLUMN event DROP NOT NULL;

ALTER TABLE "general"
    ALTER COLUMN exchange_exten SET DEFAULT NULL::character varying;

ALTER TABLE linefeatures
    ALTER COLUMN protocol DROP NOT NULL;

ALTER TABLE paging
    DROP COLUMN IF EXISTS callnotbusy;

ALTER TABLE parkinglot
    ALTER COLUMN calltransfers SET DEFAULT NULL::character varying,
    ALTER COLUMN callreparking SET DEFAULT NULL::character varying,
    ALTER COLUMN callhangup SET DEFAULT NULL::character varying,
    ALTER COLUMN callrecording SET DEFAULT NULL::character varying,
    ALTER COLUMN musicclass SET DEFAULT NULL::character varying;

ALTER TABLE queue
    ALTER COLUMN defaultrule SET DEFAULT NULL::character varying;

ALTER TABLE recording
    ALTER COLUMN agent_id SET NOT NULL;

ALTER TABLE schedule
    ALTER COLUMN timezone SET DEFAULT NULL::character varying,
    ALTER COLUMN fallback_actionid SET DEFAULT NULL::character varying,
    ALTER COLUMN fallback_actionargs SET DEFAULT NULL::character varying;

ALTER TABLE schedule_time
    ALTER COLUMN hours SET DEFAULT NULL::character varying,
    ALTER COLUMN weekdays SET DEFAULT NULL::character varying,
    ALTER COLUMN monthdays SET DEFAULT NULL::character varying,
    ALTER COLUMN months SET DEFAULT NULL::character varying,
    ALTER COLUMN actionid SET DEFAULT NULL::character varying,
    ALTER COLUMN actionargs SET DEFAULT NULL::character varying;

ALTER TABLE trunkfeatures
    ALTER COLUMN protocol DROP NOT NULL;

ALTER TABLE usercustom
    ALTER COLUMN protocol DROP DEFAULT,
    ALTER COLUMN protocol DROP NOT NULL;

ALTER TABLE useriax
    ALTER COLUMN type DROP NOT NULL,
    ALTER COLUMN protocol DROP DEFAULT,
    ALTER COLUMN protocol DROP NOT NULL;

ALTER TABLE usersip
    ALTER COLUMN transport SET DEFAULT NULL::character varying,
    ALTER COLUMN remotesecret SET DEFAULT NULL::character varying,
    ALTER COLUMN callbackextension SET DEFAULT NULL::character varying,
    ALTER COLUMN contactpermit SET DEFAULT NULL::character varying,
    ALTER COLUMN contactdeny SET DEFAULT NULL::character varying,
    ALTER COLUMN unsolicited_mailbox SET DEFAULT NULL::character varying,
    ALTER COLUMN disallowed_methods SET DEFAULT NULL::character varying,
    ALTER COLUMN type DROP NOT NULL,
    ALTER COLUMN protocol DROP DEFAULT,
    ALTER COLUMN protocol DROP NOT NULL;

COMMIT;
