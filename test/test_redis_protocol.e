note
	description: "[
		Eiffel tests that can be executed by testing tool.
	]"
	author: "EiffelStudio test wizard"
	date: "$Date$"
	revision: "$Revision$"
	testing: "type/manual"

class
	TEST_REDIS_PROTOCOL

inherit
	EQA_TEST_SET
		redefine
			on_prepare,
			on_clean
		end

feature {NONE} -- Events

	on_prepare
			-- <Precursor>
		do
		end

	on_clean
			-- <Precursor>
		do
		end

feature -- Test routines

	test_redis_commands_commons_and_string
			-- New test routine
		local
			redis: REDIS_API
			params : HASH_TABLE [STRING_8, STRING_8]
			l_result : LIST[STRING]
			l_number_keys : INTEGER
			i : INTEGER
		do
			create redis.make
			redis.flush_all
			assert ("Expected size 0", 0 = redis.db_size)
			redis.set ("key1", "value1")
			redis.set ("key2", "value2")
			redis.set ("key3", "value3")
			assert ("Expected size 3", 3 = redis.db_size)
			create params.make (5)
			params.force ("value4", "key1")
			params.force ("value5", "key2")
			params.force ("value6", "key3")
			params.force ("value7", "key4")
			params.force ("value9", "key5")
			redis.mset (params)
			assert ("Expected size 5", 5 = redis.db_size)
			l_result := redis.mget(<<"key1","key2","key3","key4","key6">>)
			assert("Expected size 5", 5 = l_result.count)
			redis.set ("delete", "value")
			assert("Expected exist true", redis.exists ("delete"))
			assert("Expected 1",1 = redis.del(<<"delete">>))
			assert("Expected not exist", not redis.exists ("delete"))
			redis.set ("delete0", "value")
			redis.set ("delete1", "value")
			redis.set ("delete2", "value")
			assert("Expected 2",2 = redis.del(<<"delete","delete0","delete2">>))
			assert("Expected not exist", not redis.exists ("delete0"))
			assert("Expected not exist", not redis.exists ("delete2"))
			l_number_keys := redis.db_size
			redis.set ("nuevaK8", "nuevoV")
			assert("Expected one more element", (l_number_keys + 1) = redis.db_size)
			assert ("Expected 1", 1 = redis.del (<<"nuevaK8">>))
			assert("Expected equal number", (l_number_keys ) = redis.db_size)
			assert("Expected -1", -1 = redis.ttl ("key1"))
			redis.expire ("key1", 5)
			assert("Expected > -1", -1 < redis.ttl ("key1"))

			from
				I := 0
			until
				i < 100000
			loop
				i := i + 1
			end
			assert("Expected False", redis.exists ("key1"))
			redis.move ("key2", 1)
			redis.select_db (1)
			assert("Expected size1", 1 = redis.db_size)
			assert("Exists Key2 in DB 1", redis.exists ("key2"))
			redis.select_db (0)
			assert("Not Exists Key2 in DB 0", not redis.exists ("key2"))
			redis.close
		end


	test_commands_on_list
		local
			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			assert ("expect 0", 0 = redis.db_size)
			assert ("Expected 1",1 = redis.rpush ("key1", "value1"))
			assert ("Expected type list", redis.type_list ~ redis.type ("key1"))
			assert ("Expected 2",2 = redis.rpush ("key1", "value2"))
			redis.close
		end

	test_wrong_type
		local
			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			redis.set ("key1", "value1")
			assert("Expected 1", 1 = redis.rpush ("key2", "value2"))
		end

	push_a_value_with_lpush_should_let_the_value_in_the_front
		local
			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			assert("Expected 1", 1 = redis.lpush ("key1", "value1"))
		end

	adding_a_value_to_a_list_implies_one_more_element
		local
			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			assert("Expected 0", 0 = redis.llen ("key1"))
			assert("Expected 1", 1 = redis.lpush ("key1", "value1"))
			redis.set ("key2", "value2")
		end


	testing_lrange
		local
			redis : REDIS_API
			l_result : LIST[STRING]
		do
			create redis.make
			redis.flush_all
			assert("Expected 1", 1 = redis.lpush ("key1", "value1"))
			assert("Expected 2", 2 = redis.lpush ("key1", "value2"))
			assert("Expected 3", 3 = redis.lpush ("key1", "value3"))
			assert("Expected 4", 4 = redis.lpush ("key1", "value4"))
			-- redis.lrange("key1", 2,4) = ["valu2,"value3","value4"]
			l_result := redis.lrange ("key1", -2,-1)
			assert ("Expected not void", l_result /= Void)
			assert ("Expected value 2 ", l_result.at(1) ~ "value2")
			assert ("Expected value 3 ", l_result.at(2) ~ "value1")
		end


	testing_ltrim
		local
			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			assert("Expected 1", 1 = redis.lpush ("key1", "value1"))
			assert("Expected 2", 2 = redis.lpush ("key1", "value2"))
			assert("Expected 3", 3 = redis.lpush ("key1", "value3"))
			assert("Expected 4", 4 = redis.lpush ("key1", "value4"))
			redis.ltrim ("key1", 0,1)
			assert ("Expected 2", 2=redis.llen ("key1"))
		end

	testing_lindex
		local
			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			assert("Expected 1", 1 = redis.lpush ("key1", "value1"))
			assert("Expected 2", 2 = redis.lpush ("key1", "value2"))
			assert("Expected 3", 3 = redis.lpush ("key1", "value3"))
			assert("Expected 4", 4 = redis.lpush ("key1", "value4"))
			assert("Expected Void", redis.lindex ("key1", 4) = Void)
			assert("Expected Void", redis.lindex ("key1", 3) ~ "value1")
		end


	testing_lset
		local
			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			assert("Expected 1", 1 = redis.lpush ("key1", "value1"))
			assert("Expected 2", 2 = redis.lpush ("key1", "value2"))
			assert("Expected 3", 3 = redis.lpush ("key1", "value3"))
			assert("Expected 4", 4 = redis.lpush ("key1", "value4"))
			redis.lset("key1",0,"newvalue4")
			assert("Expected nuewvalue4", redis.lindex("key1",0) ~ "newvalue4")
		end

	testing_let_out_of_range_index_will_generate_an_error
		local
			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			assert("Expected 1", 1 = redis.lpush ("key1", "value1"))
			assert("Expected 2", 2 = redis.lpush ("key1", "value2"))
			assert("Expected 3", 3 = redis.lpush ("key1", "value3"))
			assert("Expected 4", 4 = redis.lpush ("key1", "value4"))
			redis.lset("key1",4,"newvalue4")
			assert("Expected error", redis.has_error)
			assert("Error description not null", redis.error_description /= Void)
		end



	testing_lrem
		-- LREM key count value 				
		-- Remove the first-N, last-N, or all the elements matching value from the List at key

		local
			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			assert("Expected 1", 1 = redis.rpush ("key1", "a"))
			assert("Expected 2", 2 = redis.rpush ("key1", "b"))
			assert("Expected 3", 3 = redis.rpush ("key1", "c"))
			assert("Expected 4", 4 = redis.rpush ("key1", "hello"))
			assert("Expected 5", 5 = redis.rpush ("key1", "x"))
			assert("Expected 6", 6 = redis.rpush ("key1", "hello"))
			assert("Expected 7", 7 = redis.rpush ("key1", "hello"))
			assert("Expected 2 removed elements", 2 = redis.lrem("key1",-2,"hello"))
			assert("Expected 5 elements", 5 = redis.llen ("key1"))
		end

	testing_lpop
		--LPOP key 						
		--Return and remove (atomically) the first element of the List at key	
		local
			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			assert("Expected 1", 1 = redis.rpush ("key1", "a"))
			assert("Expected 2", 2 = redis.rpush ("key1", "b"))
			assert("Expected 3", 3 = redis.rpush ("key1", "c"))
			assert("Expected 4", 4 = redis.rpush ("key1", "hello"))
			assert("Expected 5", 5 = redis.rpush ("key1", "x"))
			assert("Expected 6", 6 = redis.rpush ("key1", "hello"))
			assert("Expected 7", 7 = redis.rpush ("key1", "hello"))
			assert("Expected element a", "a" ~ redis.lpop("key1"))
			assert("Expected 6 elements", 6 = redis.llen ("key1"))
			assert("Expected Void", Void = redis.lpop ("key2"))
		end

	testing_rpop
		--RPOP key 						
		--Return and remove (atomically) the last element of the List at key
		local
			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			assert("Expected 1", 1 = redis.rpush ("key1", "a"))
			assert("Expected 2", 2 = redis.rpush ("key1", "b"))
			assert("Expected 3", 3 = redis.rpush ("key1", "c"))
			assert("Expected 4", 4 = redis.rpush ("key1", "hello"))
			assert("Expected 5", 5 = redis.rpush ("key1", "x"))
			assert("Expected 6", 6 = redis.rpush ("key1", "hello"))
			assert("Expected 7", 7 = redis.rpush ("key1", "hello"))
			assert("Expected element hello", "hello" ~ redis.rpop("key1"))
			assert("Expected 6 elements", 6 = redis.llen ("key1"))
			assert("Expected Void", Void = redis.lpop ("key2"))
		end

	testing_sadd
		-- SADD key member 					
		-- Add the specified member to the Set value at key
		local
			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			assert("Expected 1", 1=redis.sadd ("key1", "element"))
			assert("Expected 0", 0=redis.sadd ("key1", "element"))
		end

	testing_srem
		-- SREM key member 					
		-- Remove the specified member from the Set value at key
		local
			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			assert("Expected 1", 1=redis.sadd ("key1", "element"))
			assert("Expected 1", 1=redis.srem ("key1", "element"))
			assert("Expected 0", 0=redis.srem ("key1", "element"))
		end

	testing_spop
		--SPOP key 						
		--Remove and return (pop) a random element from the Set value at key
		local
			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			assert("Expected 1", 1=redis.sadd ("key1", "element"))
			assert("Expected element", "element" ~ redis.spop("key1"))
			assert("Expected Void", redis.spop("key") = Void )
		end

	testing_scard
		-- SCARD key 						
		-- Return the number of elements (the cardinality) of the Set at key
		local

			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			assert("Expected 1", 1=redis.sadd ("key1", "element"))
			assert("Expected 0", 0=redis.sadd ("key1", "element"))
			assert("Expected 1", 1=redis.sadd ("key1", "element1"))
			assert("Expected 2", 2 = redis.scard("key1") )
		end

	testing_sismember
		-- SISMEMBER 	key member 					
		-- Test if the specified value is a member of the Set at key	
		local

			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			assert("Expected 1", 1=redis.sadd ("key1", "element"))
			assert("Expected 0", 0=redis.sadd ("key1", "element"))
			assert("Expected 1", 1=redis.sadd ("key1", "element1"))
			assert("Expected 2", 2 = redis.scard("key1") )
			assert("Expected true", redis.sismember("key1","element"))
			assert("Expected false", not redis.sismember("key1","noelement"))
		end

	testing_sinter
		-- SINTER key1 key2 ... keyN 				
		-- Return the intersection between the Sets stored at key1, key2, ..., keyN
		local

			redis : REDIS_API
			l_result : LIST[STRING]
		do
			create redis.make
			redis.flush_all
			--Set Key= [a,b,c]
			assert("Expected 1", 1=redis.sadd ("key", "a"))
			assert("Expected 1", 1=redis.sadd ("key", "b"))
			assert("Expected 1", 1=redis.sadd ("key", "c"))
			--Set Key1= [b,d]
			assert("Expected 1", 1=redis.sadd ("key1", "b"))
			assert("Expected 1", 1=redis.sadd ("key1", "d"))

			l_result := redis.sinter (<<"key","key1">>)
			assert ("Expected no empty", not l_result.is_empty)
			l_result := redis.sinter (<<"key","key1","key4">>)
			assert ("Expected empty", l_result.is_empty)
		end

	testing_smove
		-- SMOVE srckey dstkey member 				
		-- Move the specified member from one Set to another atomically
		local

			redis : REDIS_API
			l_result : LIST[STRING]
		do
			create redis.make
			redis.flush_all
			--Set Key= [a,b,c]
			assert("Expected 1", 1=redis.sadd ("key", "a"))
			assert("Expected 1", 1=redis.sadd ("key", "b"))
			assert("Expected 1", 1=redis.sadd ("key", "c"))
			--Set Key1= [b,d]
			assert("Expected 1", 1=redis.sadd ("key1", "b"))
			assert("Expected 1", 1=redis.sadd ("key1", "d"))

			assert("Expected 1", 1 = redis.smove("key","key1","a"))
			assert("Expected 0", 0 = redis.smove("key","key1","a"))

			assert("Expected 1", 1 = redis.smove("key","key3","b"))
		end

	testing_sinterstore
		-- SINTERSTORE 	dstkey key1 key2 ... keyN 			
		-- Compute the intersection between the Sets stored at key1, key2, ..., keyN, and store the resulting Set at dstkey	
		local

			redis : REDIS_API
		do
			create redis.make
			redis.flush_all
			--Set Key= [a,b,c]
			assert("Expected 1", 1=redis.sadd ("key", "a"))
			assert("Expected 1", 1=redis.sadd ("key", "b"))
			assert("Expected 1", 1=redis.sadd ("key", "c"))
			--Set Key1= [b,d]
			assert("Expected 1", 1=redis.sadd ("key1", "b"))
			assert("Expected 1", 1=redis.sadd ("key1", "d"))
			redis.sinterstore (<<"destkey","key","key1">>)
			assert ("Expected 1 element",1=redis.scard ("destkey"))
		end

	testing_union
		--SUNION key1 key2 ... keyN 				
		--Return the union between the Sets stored at key1, key2, ..., keyN	
		local

			redis : REDIS_API
			l_result : LIST[STRING]
		do
			create redis.make
			redis.flush_all
			--Set Key= [a,b,c]
			assert("Expected 1", 1=redis.sadd ("key", "a"))
			assert("Expected 1", 1=redis.sadd ("key", "b"))
			assert("Expected 1", 1=redis.sadd ("key", "c"))
			--Set Key1= [b,d]
			assert("Expected 1", 1=redis.sadd ("key1", "b"))
			assert("Expected 1", 1=redis.sadd ("key1", "d"))
			l_result := redis.sunion(<<"key","key1">>)
			assert ("Expected 4 element",l_result.count = 4)
		end

	testing_union_store
		--SUNIONSTORE 	dstkey key1 key2 ... keyN 			
		--Compute the union between the Sets stored at key1, key2, ..., keyN, and store the resulting Set at dstkey
		local

			redis : REDIS_API
			l_result : LIST[STRING]
		do
			create redis.make
			redis.flush_all
			--Set Key= [a,b,c]
			assert("Expected 1", 1=redis.sadd ("key", "a"))
			assert("Expected 1", 1=redis.sadd ("key", "b"))
			assert("Expected 1", 1=redis.sadd ("key", "c"))
			--Set Key1= [b,d]
			assert("Expected 1", 1=redis.sadd ("key1", "b"))
			assert("Expected 1", 1=redis.sadd ("key1", "d"))
			redis.sunionstore(<<"setU","key","key1">>)
			assert ("Expected 4 element",redis.scard ("setU") = 4)
		end


	testing_sdiff
		--SDIFF key1 key2 ... keyN 				
		--Return the difference between the Set stored at key1 and all the Sets key2, ..., keyN
		local

			redis : REDIS_API
			l_result : LIST[STRING]
		do
			create redis.make
			redis.flush_all
			--Set Key= [a,b,c]
			assert("Expected 1", 1=redis.sadd ("key", "a"))
			assert("Expected 1", 1=redis.sadd ("key", "b"))
			assert("Expected 1", 1=redis.sadd ("key", "c"))
			--Set Key1= [b,d]
			assert("Expected 1", 1=redis.sadd ("key1", "b"))
			assert("Expected 1", 1=redis.sadd ("key1", "d"))
			l_result := redis.sdiff(<<"key","key1">>)
			l_result.compare_objects
			assert ("Expected 2 element",l_result.count = 2)
			assert ("Has element a",l_result.has ("a"))
			assert ("Has element c",l_result.has ("c"))
		end


	testing_sdiff_store
		--SDIFFSTORE dstkey key1 key2 ... keyN 			
		-- Compute the difference between the Set key1 and all the Sets key2, ..., keyN, and store the resulting 									
		-- Set at dstkey
		local

			redis : REDIS_API
			l_result : LIST[STRING]
		do
			create redis.make
			redis.flush_all
			--Set Key= [a,b,c]
			assert("Expected 1", 1=redis.sadd ("key", "a"))
			assert("Expected 1", 1=redis.sadd ("key", "b"))
			assert("Expected 1", 1=redis.sadd ("key", "c"))
			--Set Key1= [b,d]
			assert("Expected 1", 1=redis.sadd ("key1", "b"))
			assert("Expected 1", 1=redis.sadd ("key1", "d"))
			redis.sdiffstore(<<"setD","key","key1">>)
			assert ("Expected 2 element",2 = redis.scard ("setD"))
		end

	testing_smembers
		--SMEMBERS 	key 						
		--Return all the members of the Set value at key
		local

			redis : REDIS_API
			l_result : LIST[STRING]
		do
			create redis.make
			redis.flush_all
			--Set Key= [a,b,c]
			assert("Expected 1", 1=redis.sadd ("key", "a"))
			assert("Expected 1", 1=redis.sadd ("key", "b"))
			assert("Expected 1", 1=redis.sadd ("key", "c"))

			l_result := redis.smembers("key")
			assert("Expected 3 elements", 3 = l_result.count)
			l_result.compare_objects
			assert ("Has element a", l_result.has ("a"))
			assert ("Has element b", l_result.has ("b"))
			assert ("Has element c", l_result.has ("c"))
		end


	testing_srandmember
		--SRANDMEMBER 	key 						
		--Return a random member of the Set value at key
		local

			redis : REDIS_API
			l_result : STRING
		do
			create redis.make
			redis.flush_all
			--Set Key= [a,b,c]
			assert("Expected 1", 1=redis.sadd ("key", "a"))
			assert("Expected 1", 1=redis.sadd ("key", "b"))
			assert("Expected 1", 1=redis.sadd ("key", "c"))

			l_result := redis.srandmember("key")
			assert("Expected is member", redis.sismember ("key", l_result))
			assert ("Expected 1", 1= redis.srem ("key", l_result))
			assert("Expected not is member", not redis.sismember ("key", l_result))
		end


end


