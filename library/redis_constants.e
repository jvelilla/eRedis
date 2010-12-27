note
	description: "Summary description for {REDIS_CONSTANTS}."
	author: ""
	date: "$Date$"
	revision: "$Revision$"

deferred class
	REDIS_CONSTANTS
feature -- Commands
	SET_Command				: STRING = "SET"
	SETNX_Command			: STRING = "SETNX"
	SETEX_Command			: STRING = "SETEX"
	GET_Command				: STRING = "GET"
	GETSET_Command			: STRING = "GETSET"
	MGET_Command			: STRING = "MGET"
	MSET_Command			: STRING = "MSET"
	MSETNX_Command			: STRING = "MSETNX"
	INCR_Command			: STRING = "INCR"
	INCRBY_Command			: STRING = "INCRBY"
	DECR_Command			: STRING = "DECR"
	DECRBY_Command			: STRING = "DECRBY"
	APPEND_Command			: STRING = "APPEND"
	SUBSTR_Command			: STRING = "SUBSTR"
	Flush_db_command		: STRING = "FLUSHDB"
	Flush_all_command		: STRING = "FLUSHALL"
	Exists_command			: STRING = "EXISTS"
	DEL_Command				: STRING = "DEL"
	TYPE_Command			: STRING = "TYPE"
	KEYS_Command			: STRING = "KEYS"
	RANDOMKEY_Command		: STRING = "RANDOMKEY"
	RENAME_Command			: STRING = "RENAME"
	RENAMENX_Command		: STRING = "RENAMENX"
	DBSIZE_Command			: STRING = "DBSIZE"
	SELECT_Command			: STRING = "SELECT"
	QUIT_Command			: STRING = "QUIT"
	ECHO_Command			: STRING = "ECHO"
	PING_Command			: STRING = "PING"
	AUTH_Command			: STRING = "AUTH"
	TTL_Command				: STRING = "TTL"
	EXPIRE_Command			: STRING = "EXPIRE"
	PERSIST_Command			: STRING = "PERSIST"
	MOVE_Command			: STRING = "MOVE"
	RPUSH_Command			: STRING = "RPUSH"
	LPUSH_Command			: STRING = "LPUSH"
	LLEN_Command			: STRING = "LLEN"
	LRANGE_Command			: STRING = "LRANGE"
	LTRIM_Command			: STRING = "LTRIM"
	LINDEX_Command			: STRING = "LINDEX"
	LSET_Command			: STRING = "LSET"
	LREM_Command			: STRING = "LREM"
	LPOP_Command			: STRING = "LPOP"
	RPOP_Command			: STRING = "RPOP"
	SADD_Command			: STRING = "SADD"
	SREM_Command			: STRING = "SREM"
	SPOP_Command			: STRING = "SPOP"
	SCARD_Command			: STRING = "SCARD"
	SISMEMBER_Command		: STRING = "SISMEMBER"
	SINTER_Command			: STRING = "SINTER"
	SMOVE_Command			: STRING = "SMOVE"
	SINTERSTORE_Command		: STRING = "SINTERSTORE"
	SUNION_Command			: STRING = "SUNION"
	SUNIONSTORE_Command		: STRING = "SUNIONSTORE"
	SDIFF_Command			: STRING = "SDIFF"
	SDIFFSTORE_Command		: STRING = "SDIFFSTORE"
	SMEMBERS_Command		: STRING = "SMEMBERS"
	SRANDMEMBER_Command 	: STRING = "SRANDMEMBER"
	BLPOP_Command			: STRING = "BLPOP"
	BRPOP_Command			: STRING = "BRPOP"
	RPOPLPUSH_Command		: STRING = "RPOPLPUSH"
	ZADD_Command			: STRING = "ZADD"
	ZREM_Command			: STRING = "ZREM"
	ZINCRBY_Command			: STRING = "ZINCRBY"
	ZRANK_Command			: STRING = "ZRANK"
	ZREVRANK_Command		: STRING = "ZREVRANK"
	ZRANGE_Command			: STRING = "ZRANGE"
	ZREVRANGE_Command		: STRING = "ZREVRANGE"
	ZRANGEBYSCORE_Command	: STRING = "ZRANGEBYSCORE"
	ZCOUNT_Command			: STRING = "ZCOUNT"
	ZCARD_Command			: STRING = "ZCARD"
	ZSCORE_Command			: STRING = "ZSCORE"
	ZREMRANGEBYRANK_Command	: STRING = "ZREMRANGEBYRANK"
	ZREMRANGEBYSCORE_Command: STRING = "ZREMRANGEBYSCORE"
	ZUNIONSTORE_Command		: STRING = "ZUNIONSTORE"
	ZINTERSTORE_Command		: STRING = "ZINTERSTORE"
	HSET_Command			: STRING = "HSET"
	HGET_Command			: STRING = "HGET"
	HSETNX_Command			: STRING = "HSETNX"
	HMSET_Command			: STRING = "HMSET"
	HMGET_Commmand			: STRING = "HMGET"
	HINCRBY_Command			: STRING = "HINCRBY"
	HEXISTS_Command 		: STRING = "HEXISTS"
	HDEL_Command			: STRING = "HDEL"
	HLEN_Command			: STRING = "HLEN"
	HGETALL_Command			: STRING = "HGETALL"
	HKEYS_Command			: STRING = "HKEYS"
	HVALS_Command			: STRING = "HVALS"
	INFO_Command			: STRING = "INFO"
	BGREWRITEAOF_Command	: STRING = "BGREWRITEAOF"
	BGSAVE_Command			: STRING = "BGSAVE"
	CONFIG_GET_Command,
	CONFIG_SET_Command,
	CONFIG_RESETSTAT_Command
							: STRING = "CONFIG"
	DEBUG_OBJECT_Command,
	DEBUG_SEGFAULT_Command	: STRING = "DEBUG"
	LASTSAVE_Command		: STRING = "LASTSAVE"
	SAVE_Command			: STRING = "SAVE"
	SHUTDOWN_Command		: STRING = "SHUTDOWN"
	SLAVEOF_Command			: STRING = "SLAVEOF"

	Redis_commands : ARRAY[STRING]
		-- List of valid redis commands
		once
			Result :=<<set_command,get_command,mget_command,mset_command,flush_db_command,flush_all_command,exists_command,del_command,
				type_command, keys_command, rename_command,dbsize_command,select_command,quit_command,ttl_command,expire_command,
				persist_command, move_command,rpush_command,lpush_command,llen_command,lrange_command,ltrim_command,lindex_command,
				lset_command,lrem_command,rpop_command,lpop_command,sadd_command,srem_command,spop_command,scard_command,sismember_command,
				sinter_command,smove_command,sinterstore_command,sunion_command,sunionstore_command,sdiff_command,sdiffstore_command,
				smembers_command,srandmember_command,blpop_command,brpop_command,rpoplpush_command,randomkey_command,getset_command,setnx_command
				,setex_command,msetnx_command,incr_command,incrby_command,decr_command,decrby_command,append_command,substr_command,
				zadd_command,zrem_command,zincrby_command,zrank_command,zrevrank_command,zrange_command,zrevrange_command,zrangebyscore_command,
				zcount_command,zcard_command,zscore_command,zremrangebyrank_command,zremrangebyscore_command,zunionstore_command,
				zinterstore_command,hset_command,hget_command,hsetnx_command,hmset_command,hmget_commmand,hincrby_command,hexists_command,
				hdel_command,hlen_command,hgetall_command,hkeys_command,hvals_command,info_command,renamenx_command,
				echo_command,ping_command,auth_command,bgrewriteaof_command,bgsave_command,config_get_command,config_set_command,
				config_resetstat_command,debug_object_command,debug_segfault_command,lastsave_command,save_command,shutdown_command,
				slaveof_command>>
		end

	WITHSCORES		: STRING ="WITHSCORES"
	LIMIT			: STRING ="LIMIT"
	WEIGHTS			: STRING ="WEIGHTS"
	AGGREGATE       : STRING ="AGGREGATE"
	SUM				: STRING ="SUM"
	MIN				: STRING ="MIN"
	MAX				: STRING ="MAX"

	aggregate_values : ARRAY [STRING]
		-- Redis aggregate values
		once
			Result :=<<sum,min,max>>
		end
feature -- Redis Types

	TYPE_NONE : STRING = "none"
		-- 	"none" if the key does not exist
	TYPE_STRING : STRING = "string"
		--"string" if the key contains a String value
	TYPE_LIST : STRING = "list"
		--"list" if the key contains a List value
	TYPE_SET : STRING = "set"
		--"set" if the key contains a Set value
	TYPE_ZSET : STRING = "zset"
		--"zset" if the key contains a Sorted Set value
	TYPE_HASH : STRING = "hash"
		--"hash" if the key contains a Hash value

	Redis_types : ARRAY[STRING]
		-- List of valid redis types
		once
			Result := <<type_hash,type_list,type_none,type_set,type_string,type_zset>>
		end

feature -- {NONE} Redis Protocol

	DEFAULT_PEER_PORT : INTEGER = 6379
	DEFAULT_PEER_HOST : STRING  = "localhost"

	CRLF        : STRING = "%R%N"
	NULL_RESPONSE : STRING ="$-1"
	NOT_EXIST_KEY :	STRING ="*-1"

	DOLLAR_BYTE : CHARACTER = '$'
	ASTERISK_BYTE : CHARACTER = '*'
	PLUS_BYTE : CHARACTER = '+'
	MINUS_BYTE : CHARACTER = '-'
	COLON_BYTE : CHARACTER = ':'

	ERROR_RESPONSE : STRING ="-ERR"
end
