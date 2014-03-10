note
	description : "test application root class"
	date        : "$Date$"
	revision    : "$Revision$"

class
	APPLICATION

inherit
	ARGUMENTS

create
	make

feature {NONE} -- Initialization

	r: REDIS_API
	port : INTEGER = 6379
	host : STRING =  "127.0.0.1"
	make
			-- Run application.
		do
--		 print ("%Ntesting command list%N")
--		 test_commands_on_list
--		 print ("%Ntesting commands common %N")
--		 test_redis_commands_commons_and_string
		 create r.make_client_by_port (port, host)
		 print ("%N" + r.info)
		end


	test_redis_commands_commons_and_string
			-- New test routine
		local
			redis: REDIS_API
			params : HASH_TABLE [STRING_8, STRING_8]
			l_result : LIST[detachable STRING]
			l_number_keys : INTEGER
			i : INTEGER
		do
			create redis.make
			redis.flush_all
			check 0 = redis.db_size end
			redis.set ("key1", "value1")
			redis.set ("key2", "value2")
			redis.set ("key3", "value3")
			check 3 = redis.db_size end
			create params.make (5)
			params.force ("value4", "key1")
			params.force ("value5", "key2")
			params.force ("value6", "key3")
			params.force ("value7", "key4")
			params.force ("value9", "key5")
			redis.mset (params)
			check 5 = redis.db_size end
			l_result := redis.mget(<<"key1","key2","key3","key4","key6">>)
			check 5 = l_result.count end
			redis.set ("delete", "value")
			check  redis.exists ("delete") end
			check 1 = redis.del(<<"delete">>) end
			check not redis.exists ("delete") end
			redis.set ("delete0", "value")
			redis.set ("delete1", "value")
			redis.set ("delete2", "value")
			check 2 = redis.del(<<"delete","delete0","delete2">>) end
			check not redis.exists ("delete0") end
			check not redis.exists ("delete2") end
			l_number_keys := redis.db_size
			redis.set ("nuevaK8", "nuevoV")
			check (l_number_keys + 1) = redis.db_size end
			check 1 = redis.del (<<"nuevaK8">>) end
			check (l_number_keys ) = redis.db_size end
			check -1 = redis.ttl ("key1") end
			redis.expire ("key1", 5)
			check  -1 < redis.ttl ("key1") end

			from
				I := 0
			until
				i < 100000
			loop
				i := i + 1
			end
			check redis.exists ("key1") end
			redis.move ("key2", 1)
			redis.select_db (1)
			check 1 = redis.db_size end
			check redis.exists ("key2") end
			redis.select_db (0)
			check not redis.exists ("key2") end
			redis.close
		end


	test_commands_on_list
		local
			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			check 0 = redis.db_size end
			check 1 = redis.rpush ("key1", "value1") end
			check redis.type_list ~ redis.type ("key1") end
			check 2 = redis.rpush ("key1", "value2") end
			redis.close
		end

end
