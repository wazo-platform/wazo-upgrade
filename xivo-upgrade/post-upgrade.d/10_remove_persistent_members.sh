#!/bin/sh

/usr/sbin/asterisk -rx "module unload chan_agent.so"
/usr/sbin/asterisk -rx "module unload app_queue.so"
/usr/sbin/asterisk -rx "database deltree Queue/PersistentMembers"
