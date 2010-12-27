note
	description: "Summary description for {REDIS_CONFIG_PARAMETERS}."
	author: ""
	date: "$Date$"
	revision: "$Revision$"

deferred class
	REDIS_CONFIG_PARAMETERS

feature -- Configuration Parameters	
	dbfilename	: STRING = "dbfilename"
	requirepass	: STRING = "requirepass"
	masterauth	: STRING = "masterauth"
	maxmemory	: STRING = "maxmemory"
	timeout		: STRING = "timeout"
	appendonly	: STRING = "appendonly"
	appendsync  : STRING = "appendsync"
	save		: STRING = "save"

end
