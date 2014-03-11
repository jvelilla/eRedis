note
	description: "[
		Eiffel tests that can be executed by test tool.
	]"
	author: "EiffelStudio test wizard"
	date: "$Date$"
	revision: "$Revision$"
	test: "type/manual"
	testing:"execution/serial"

class
	TEST_REDIS_2

inherit
	EQA_TEST_SET
		redefine
			on_prepare,
			on_clean
		end
	REDIS_CONFIG_PARAMETERS
		undefine
			default_create
		end

feature {NONE} -- Events


	on_prepare
			-- <Precursor>
		do
			create redis.make_client_by_port (port, host)
			redis.flush_all
		end

	on_clean
			-- <Precursor>
		do
			redis.flush_all
			redis.close
		end

feature {NONE} -- implementation
	redis : REDIS_API

feature -- Conditions
	test_for_all_not
		do
			assert("True", redis.for_all_not_null (<<"a","v">>))
			assert("False", not redis.for_all_not_null (<<"a",Void>>))
		end

feature -- String operations

	get_what_was_set
			-- SET key value Set a key to a string value
		local
			big_value : STRING
		do
			big_value := "[
			Hola como estas
			todo bien espero que ande
			esto puede ser una gran
			prueba
			]"
			redis.set("key",big_value)
			assert("Expected big_value",big_value ~ redis.get("key"))

			big_value :="Hola como estas%R%Ntodo bien espero que ande%R%Nesto puede ser una gran prueba"
			redis.set("key",big_value)
			assert("Expected big_value",big_value ~ redis.get("key"))

			redis.set("key","value")
			io.set_output_default
			print (redis.get("key"))
			assert("Expected value","value" ~ redis.get("key"))
		end

	get_multiple_values_what_where_set
		local
			l_result : LIST[detachable STRING]
		do
			redis.set ("key1", "value1")
			redis.set ("key2", "value2")
			redis.set ("key3", "value3")
			redis.set ("key4", "value4")

			l_result := redis.mget(<<"key1","key2","key3","key4">>)
			assert ("Expected not void", l_result /= Void)
			assert ("Expected value1", l_result.at (1) ~ "value1")
			assert ("Expected value2", l_result.at (2) ~ "value2")
			assert ("Expected value3", l_result.at (3) ~ "value3")
			assert ("Expected value4", l_result.at (4) ~ "value4")
		end

	get_multiple_values_what_where_set_and_key_does_not_exist
		local
			l_result : LIST[detachable STRING]
		do
			redis.set ("key1", "value5")
			redis.set ("key2", "value6")
			redis.set ("key3", "value7")
			redis.set ("key4", "value8")

			l_result := redis.mget(<<"key1","key2","key999","key4">>)
			assert ("Expected not void", l_result /= Void)
			assert ("Expected value1", l_result.at (1) ~ "value5")
			assert ("Expected Void", l_result.at (3) = Void)
			assert ("Expected value4", l_result.at (4) ~ "value8")
		end

	get_multiple_values_what_where_multi_set
		local
			l_result : LIST[detachable  STRING]
			l_params : HASH_TABLE[STRING,STRING]
		do
			create l_params.make (4)
			l_params.put ("value10", "key6")
			l_params.put ("value4", "key5")
			l_params.put ("value3", "key10")
			l_params.put ("value9", "key9")

			redis.mset(l_params)

			l_result := redis.mget(<<"key6","key5","key10","key9">>)
			assert ("Expected not void", l_result /= Void)
			assert ("Expected value1", l_result.at (1) ~ "value10")
			assert ("Expected value4", l_result.at (2) ~ "value4")
			assert ("Expected value3", l_result.at (3) ~ "value3")
			assert ("Expected value9", l_result.at (4) ~ "value9")
		end

	check_after_set_that_the_key_exist
		do
			redis.set ("existsKey", "value")
			assert("Expected true",redis.exists("existsKey"))
		end

	check_after_delete_the_key_does_not_exist
		do
			redis.set ("delete", "value")
			assert("Expected exist true", redis.exists ("delete"))
			assert("Expected 1",1 = redis.del(<<"delete">>))
			assert("Expected not exist", not redis.exists ("delete"))
		end

	check_after_delete_some_keys_does_not_exist
		do
			redis.set ("delete0", "value")
			redis.set ("delete1", "value")
			redis.set ("delete2", "value")
			assert("Expected 2",2 = redis.del(<<"delete","delete0","delete2">>))
			assert("Expected not exist", not redis.exists ("delete0"))
			assert("Expected not exist", not redis.exists ("delete2"))
		end

	check_key_type_should_be_string_or_null
		do
			redis.set ("keyString", "value")
			assert ("Expected type_string", redis.type("keyString") ~ redis.type_string)
		end

	get_keys_using_pattern
		local
			l_result : LIST[detachable STRING]
		do
			redis.set ("foo", "value")
			redis.set ("foobar","value")
			l_result := redis.keys ("foo*")
			assert("Expected size 2", l_result.count = 2)
		end



test_redis_commands_commons_and_string
			-- New test routine
		local
			params : HASH_TABLE [STRING_8, STRING_8]
			l_result : LIST[detachable STRING]
			l_number_keys : INTEGER
			i : INTEGER
		do
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
		end

	test_setnx_key_does_not_exist_should_insert_it_and_return_1
		--SETNX key value 					
		--Set a key to a string value if the key does not exist
		do
			assert("Expected 1", 1 = redis.setnx ("key", "value"))
			assert("Expected exists key", redis.exists ("key"))
		end

	test_setnx_key_exist_should_not_insert_it_and_return_0
		--SETNX key value 					
		--Set a key to a string value if the key does not exist
		do
			redis.set ("key", "value")
			assert("Expected 0", 0 = redis.setnx ("key", "valueNX"))
			assert("Expected value ", redis.get ("key") ~ "value")
		end

	test_setex
		--SETEX key time value 					
		--Set+Expire combo command
		do
			redis.setex("key", 100, "value")
			assert("Expected >0", redis.ttl ("key") > 0)
		end

	test_msetnx_set_multiple_keys_that_does_exist_return_1
		--MSETNX  key1 value1 key2 value2 ... keyN valueN 	
		-- Set multiple keys to multiple values in a single atomic operation if none of the keys already exist
		local
			params : HASH_TABLE[STRING,STRING]
		do
			create params.make (3)
			params.force ("value4", "key1")
			params.force ("value5", "key2")
			params.force ("value6", "key3")
			assert("Expected 1", 1 = redis.msetnx(params))
			assert("Expected value", redis.get ("key1") ~ "value4")
			assert("Expected value", redis.get ("key2") ~ "value5")
			assert("Expected value", redis.get ("key3") ~ "value6")
		end

	test_msetnx_set_multiple_keys_that_exist_return_0
		--MSETNX  key1 value1 key2 value2 ... keyN valueN 	
		-- Set multiple keys to multiple values in a single atomic operation if none of the keys already exist
		local
			params : HASH_TABLE[STRING,STRING]
		do
			redis.set ("key3", "valu3")
			create params.make (3)
			params.force ("value4", "key1")
			params.force ("value5", "key2")
			params.force ("value6", "key3")
			assert("Expected 0", 0 = redis.msetnx(params))
		end


	test_incr
		--INCR 	key 						
		--Increment the integer value of key		
		do
			assert("Expected 1", 1 = redis.incr("A"))
			assert("Expected 2", 2 = redis.incr("A"))
		end

	test_incr_requirements
		do
			redis.set ("key1", "hola")
			if redis.exists("key1") implies( (redis.type ("key1") ~ redis.type_string) and then redis.get("key1").is_integer_64 ) then
				assert("Not expected", False)
			else
				assert("Expected true",true)
			end
		end

	test_incr_on_exist_key_should_increment_the_value_by_one
		do
			redis.set ("key","10")
			assert("Expected 11", 11 = redis.incr ("key"))
		end

	test_incrby
		---INCRBY key integer 					
		--Increment the integer value of key by integer
	 	do
	 		assert("Expect 5", 5=redis.incrby("key",5))
	 	end


	test_incrby_negative
		--INCRBY key integer 					
		--Increment the integer value of key by integer
	 	do
	 		redis.set ("key", "-5")
	 		assert("Expect 0", 0=redis.incrby("key",5))
	 	end

	 test_decr
	 	--DECR key 						
	 	--Decrement the integer value of key
	 	do
	 		assert("Expect -1", -1=redis.decr("key"))
	 	end

	 test_decr_key_exist
	 	--DECR key 						
	 	--Decrement the integer value of key
	 	do
	 		redis.set ("key", "5")
	 		assert("Expect 4", 4=redis.decr("key"))
	 	end

	 test_decr_by
		-- DECRBY key integer 					
		-- Decrement the integer value of key by integer
	 	do
	 		assert("Expected -5", -5 = redis.decrby ("key",5))
	 		assert("Expected 5", 5 = redis.decrby ("key1",-5))
	 	end

	test_append
		--APPEND key value 					
		--Append the specified string to the string stored at key
		do
			assert("Expected 2", 2 = redis.append("key","aa"))
		end

	test_append_key_exists
		--APPEND key value 					
		--Append the specified string to the string stored at key
		do
			redis.set ("key", "bbb")
			assert("Expected 5", 5 = redis.append("key","aa"))
		end

	test_substr
		--SUBSTR key start end 					
		--Return a substring of a larger string
		do
			redis.set ("key", "Return a substring of a larger string")
			assert("Expected Return", "Return" ~ redis.substR("key",0,5))
		end


feature -- Redis Connection
	test_echo
		do
			assert ("Expected echo", redis.echo ("echo") ~ "echo")
		end


	test_ping
		do
			assert ("Expected PONG", redis.ping  ~ "PONG")
		end


	test_auth
		--AUTH password
		--Authenticate to the server  	
		do
			redis.auth ("password")
			assert ("Not has error", not redis.has_error)
		end
feature -- Redis Common Operations

	test_renamenx
		--RENAMENX key newkey
		--Rename a key, only if the new key does not exist
		do
			redis.set ("k","val")
			assert ("Expected 1", redis.renamenx("k","newk") = 1)
			assert ("Expected False", not redis.exists ("k"))
		end

	rename_keys_old_and_new_are_differents
		do
			redis.set ("oldkey", "value")
			redis.rename_key ("oldkey","newkey")
			assert("Expected value", redis.get ("newkey") ~ "value"  )
		end

	rename_keys_old_and_new_are_equals_should_fail
		do
			redis.set ("oldkey", "value")
			redis.rename_key ("oldkey","oldkey")
			assert ("not implemented", False)
		end

	get_the_number_of_key_after_set_should_be_one_more_key
		local
			l_number_keys : INTEGER
		do
			l_number_keys := redis.db_size
			redis.set ("nuevaK8", "nuevoV")
			assert("Expected one more element", (l_number_keys + 1) = redis.db_size)
			assert ("Expected 1", 1 = redis.del (<<"nuevaK8">>))
			assert("Expected equal number", (l_number_keys ) = redis.db_size)
		end

	random_key_void_if_db_is_empty
		do
			assert ("Expected void",redis.randomkey = Void)
		end

	random_key_not_void_if_db_not_is_empty
		do
			redis.set ("key1","value1")
			redis.set ("key3","value2")
			assert ("Expected not void",redis.randomkey /= Void)
		end

	get_db_index
		do
			redis.select_db (1)
			assert("Expected 0", 0 = redis.db_size)
		end

	delete
		local
			l_number_keys : INTEGER
		do
			l_number_keys := redis.db_size
			assert("Equal Zero", l_number_keys = 0)
			redis.set ("key", "value")
			redis.flush_db
			l_number_keys := redis.db_size
			assert("Equal zero", l_number_keys = 0)
		end

	get_set_return_the_old_value_and_set_a_new_one
		-- GETSET key value 					
		-- Set a key to a string returning the old value of the key
		do
			redis.set ("key1", "oldvalue")
			assert("Expected oldvalue", redis.getset("key1","newvalue")~"oldvalue")
			assert("Expected newvalue", redis.get ("key1") ~ "newvalue")
		end




feature -- Redis Operations on List
	test_commands_on_list
		do
			assert ("expect 0", 0 = redis.db_size)
			assert ("Expected 1",1 = redis.rpush ("key1", "value1"))
			assert ("Expected type list", redis.type_list ~ redis.type ("key1"))
			assert ("Expected 2",2 = redis.rpush ("key1", "value2"))
		end

	test_wrong_type
		do
			redis.set ("key1", "value1")
			assert("Expected 1", 1 = redis.rpush ("key2", "value2"))
		end

	push_a_value_with_lpush_should_let_the_value_in_the_front
		do
			assert("Expected 1", 1 = redis.lpush ("key1", "value1"))
		end

	adding_a_value_to_a_list_implies_one_more_element
		do
			assert("Expected 0", 0 = redis.llen ("key1"))
			assert("Expected 1", 1 = redis.lpush ("key1", "value1"))
			redis.set ("key2", "value2")
		end


	test_lrange
		local
			l_result : LIST[detachable STRING]
		do
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


	test_ltrim
		do
			assert("Expected 1", 1 = redis.lpush ("key1", "value1"))
			assert("Expected 2", 2 = redis.lpush ("key1", "value2"))
			assert("Expected 3", 3 = redis.lpush ("key1", "value3"))
			assert("Expected 4", 4 = redis.lpush ("key1", "value4"))
			redis.ltrim ("key1", 0,1)
			assert ("Expected 2", 2=redis.llen ("key1"))
		end

	test_lindex
		do
			assert("Expected 1", 1 = redis.lpush ("key1", "value1"))
			assert("Expected 2", 2 = redis.lpush ("key1", "value2"))
			assert("Expected 3", 3 = redis.lpush ("key1", "value3"))
			assert("Expected 4", 4 = redis.lpush ("key1", "value4"))
			assert("Expected Void", redis.lindex ("key1", 4) = Void)
			assert("Expected Void", redis.lindex ("key1", 3) ~ "value1")
		end


	test_lset
		do
			assert("Expected 1", 1 = redis.lpush ("key1", "value1"))
			assert("Expected 2", 2 = redis.lpush ("key1", "value2"))
			assert("Expected 3", 3 = redis.lpush ("key1", "value3"))
			assert("Expected 4", 4 = redis.lpush ("key1", "value4"))
			redis.lset("key1",0,"newvalue4")
			assert("Expected nuewvalue4", redis.lindex("key1",0) ~ "newvalue4")
		end

	test_let_out_of_range_index_will_generate_an_error
		do
			assert("Expected 1", 1 = redis.lpush ("key1", "value1"))
			assert("Expected 2", 2 = redis.lpush ("key1", "value2"))
			assert("Expected 3", 3 = redis.lpush ("key1", "value3"))
			assert("Expected 4", 4 = redis.lpush ("key1", "value4"))
			redis.lset("key1",4,"newvalue4")
			assert("Expected error", redis.has_error)
			assert("Error description not null", redis.error_description /= Void)
		end



	test_lrem
		-- LREM key count value 				
		-- Remove the first-N, last-N, or all the elements matching value from the List at key
		do
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

	test_lpop
		--LPOP key 						
		--Return and remove (atomically) the first element of the List at key	
		do
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

	test_rpop
		--RPOP key 						
		--Return and remove (atomically) the last element of the List at key
		do
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


 	test_rpop_lpush
		--RPOPLPUSH srckey dstkey
 		--Return and remove (atomically) the last element of the source List stored at srckey and push the same 									
 		-- element to the destination List stored at dstkey
		do
			assert("Expected 1", 1 = redis.rpush ("key1", "a"))
			assert("Expected 2", 2 = redis.rpush ("key1", "b"))
			assert("Expected 3", 3 = redis.rpush ("key1", "c"))
			assert("Expected 4", 4 = redis.rpush ("key1", "hello"))
			assert("Expected 5", 5 = redis.rpush ("key1", "x"))
			assert("Expected 6", 6 = redis.rpush ("key1", "hello"))
			assert("Expected 7", 7 = redis.rpush ("key1", "hello"))
			assert("Expected element hello", "hello" ~ redis.rpoplpush("key1","key2"))
			assert("Expected 6 elements", 6 = redis.llen ("key1"))
			assert("Expected 1 element", 1 = redis.llen ("key2"))
		end
feature -- Redis Operations on Sets
	test_sadd
		-- SADD key member 					
		-- Add the specified member to the Set value at key
		do
			assert("Expected 1", 1=redis.sadd ("key1", "element"))
			assert("Expected 0", 0=redis.sadd ("key1", "element"))
		end

	test_srem
		-- SREM key member 					
		-- Remove the specified member from the Set value at key
		do
			assert("Expected 1", 1=redis.sadd ("key1", "element"))
			assert("Expected 1", 1=redis.srem ("key1", "element"))
			assert("Expected 0", 0=redis.srem ("key1", "element"))
		end

	test_spop
		--SPOP key 						
		--Remove and return (pop) a random element from the Set value at key
		do
			assert("Expected 1", 1=redis.sadd ("key1", "element"))
			assert("Expected element", "element" ~ redis.spop("key1"))
			assert("Expected Void", redis.spop("key") = Void )
		end

	test_scard
		-- SCARD key 						
		-- Return the number of elements (the cardinality) of the Set at key
		do
			assert("Expected 1", 1=redis.sadd ("key1", "element"))
			assert("Expected 0", 0=redis.sadd ("key1", "element"))
			assert("Expected 1", 1=redis.sadd ("key1", "element1"))
			assert("Expected 2", 2 = redis.scard("key1") )
		end

	test_sismember
		-- SISMEMBER 	key member 					
		-- Test if the specified value is a member of the Set at key	
		do
			assert("Expected 1", 1=redis.sadd ("key1", "element"))
			assert("Expected 0", 0=redis.sadd ("key1", "element"))
			assert("Expected 1", 1=redis.sadd ("key1", "element1"))
			assert("Expected 2", 2 = redis.scard("key1") )
			assert("Expected true", redis.sismember("key1","element"))
			assert("Expected false", not redis.sismember("key1","noelement"))
		end

	test_sinter
		-- SINTER key1 key2 ... keyN 				
		-- Return the intersection between the Sets stored at key1, key2, ..., keyN
		local
			l_result : LIST[detachable STRING]
		do
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

	test_smove
		-- SMOVE srckey dstkey member 				
		-- Move the specified member from one Set to another atomically
		do
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

	test_sinterstore
		-- SINTERSTORE 	dstkey key1 key2 ... keyN 			
		-- Compute the intersection between the Sets stored at key1, key2, ..., keyN, and store the resulting Set at dstkey	
		do
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

	test_union
		--SUNION key1 key2 ... keyN 				
		--Return the union between the Sets stored at key1, key2, ..., keyN	
		local
			l_result : LIST[detachable STRING]
		do
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

	test_union_store
		--SUNIONSTORE 	dstkey key1 key2 ... keyN 			
		--Compute the union between the Sets stored at key1, key2, ..., keyN, and store the resulting Set at dstkey
		local
			l_result : LIST[STRING]
		do
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


	test_sdiff
		--SDIFF key1 key2 ... keyN 				
		--Return the difference between the Set stored at key1 and all the Sets key2, ..., keyN
		local
			l_result : LIST[detachable STRING]
		do
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


	test_sdiff_store
		--SDIFFSTORE dstkey key1 key2 ... keyN 			
		-- Compute the difference between the Set key1 and all the Sets key2, ..., keyN, and store the resulting 									
		-- Set at dstkey
		local
			l_result : LIST[STRING]
		do
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

	test_smembers
		--SMEMBERS 	key 						
		--Return all the members of the Set value at key
		local
			l_result : LIST[detachable STRING]
		do
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


	test_srandmember
		--SRANDMEMBER 	key 						
		--Return a random member of the Set value at key
		do
			--Set Key= [a,b,c]
			assert("Expected 1", 1=redis.sadd ("key", "a"))
			assert("Expected 1", 1=redis.sadd ("key", "b"))
			assert("Expected 1", 1=redis.sadd ("key", "c"))

			if attached redis.srandmember("key") as l_result then
				assert("Expected is member", redis.sismember ("key", l_result))
				assert ("Expected 1", 1= redis.srem ("key", l_result))
				assert("Expected not is member", not redis.sismember ("key", l_result))
			else
				assert ("Failed:test_srandmember", False)
			end
		end

feature	-- Sorted Sets

	test_zadd
		--ZADD 	key score member 			
		--Add the specified member to the Sorted Set value at key or update the score if it already exist	
		do
			assert("expected 1", 1=redis.zadd("a_key", 10.0, "a_value"))
			assert("expected 0", 0=redis.zadd("a_key", 11.1, "a_value"))
		end

	test_zrem
		--ZREM key member 				
		--Remove the specified member from the Sorted Set value at key
		do
			assert("expected 1", 1=redis.zadd("a_key", 10.0, "a_value"))
			assert("expected 1", 1=redis.zrem("a_key","a_value"))
			assert("expected 0", 0=redis.zrem("a_key","a_value"))
		end

	test_zincrby
		--ZINCRBY key increment member 			
		--If the member already exists increment its score by increment, otherwise add the member setting increment as score
		do
			assert("Expected 5", redis.zincrby("key",10.5,"value") ~ "10.5")
			assert("Expected 5", redis.zincrby("key",5,"value") ~ "15.5" )
		end

	test_zrank
		--ZRANK key member 				
		--Return the rank (or index) or member in the sorted set at key, with scores being ordered from low to high
		do
			assert("Expected 1", 1 = redis.zadd ("key", 1, "value1"))
			assert("Expected 1", 1 = redis.zadd ("key", 5, "value2"))
			assert("Expected 1", 1 = redis.zadd ("key", 2, "value3"))
			assert("Expected 1", 1 = redis.zadd ("key", 0.9, "value4"))
			assert("Expected -1", -1 = redis.zrank("key","value13"))
			assert("Expected 2", 2 = redis.zrank("key","value3"))
		end

	test_revrank
		--ZREVRANK key member 				
		--Return the rank (or index) or member in the sorted set at key, with scores being ordered from high to low
		do
			assert("Expected 1", 1 = redis.zadd ("key", 1, "value1"))
			assert("Expected 1", 1 = redis.zadd ("key", 5, "value2"))
			assert("Expected 1", 1 = redis.zadd ("key", 2, "value3"))
			assert("Expected 1", 1 = redis.zadd ("key", 0.9, "value4"))
			assert("Expected -1", -1 = redis.zrevrank("key","value13"))
			assert("Expected 1", 1 = redis.zrevrank("key","value3"))
		end

	test_zrange
		--ZRANGE key start end 				
		--Return a range of elements from the sorted set at key
		local
			l_result : LIST [detachable STRING]
		do
			assert("Expected 1", 1 = redis.zadd ("key", 1, "value1"))
			assert("Expected 1", 1 = redis.zadd ("key", 5, "value2"))
			assert("Expected 1", 1 = redis.zadd ("key", 2, "value3"))
			assert("Expected 1", 1 = redis.zadd ("key", 1.9, "value4"))
			assert("Expected 1", 1 = redis.zadd ("key", 4, "value5"))
			assert("Expected 1", 1 = redis.zadd ("key", 7, "value6"))
			assert("Expected 1", 1 = redis.zadd ("key", 7.9, "value7"))
			assert("Expected 1", 1 = redis.zadd ("key", 3.9, "value8"))
			l_result := redis.zrange("key",2,4)
			assert ("Expected element value3", "value3" ~ l_result.at (1))
			assert ("Expected element value8", "value8" ~ l_result.at (2))
			assert ("Expected element value5", "value5" ~ l_result.at (3))
		end

	test_zrange_withscores
		--ZRANGE key start end 				
		--Return a range of elements from the sorted set at key
		local
			l_result : LIST [TUPLE[detachable STRING, detachable STRING]]
			l_tuple : TUPLE[detachable STRING, detachable STRING]
		do
			assert("Expected 1", 1 = redis.zadd ("key", 1, "value1"))
			assert("Expected 1", 1 = redis.zadd ("key", 5, "value2"))
			assert("Expected 1", 1 = redis.zadd ("key", 2, "value3"))
			assert("Expected 1", 1 = redis.zadd ("key", 1.9, "value4"))
			assert("Expected 1", 1 = redis.zadd ("key", 4, "value5"))
			assert("Expected 1", 1 = redis.zadd ("key", 7, "value6"))
			assert("Expected 1", 1 = redis.zadd ("key", 7.9, "value7"))
			assert("Expected 1", 1 = redis.zadd ("key", 3.9, "value8"))
			l_result := redis.zrange_withscores("key",2,4)
			l_tuple := l_result.at (1)
			assert ("Expected element [value3,2]", l_tuple[1] ~ "value3" and l_tuple[2]~"2")
			l_tuple := l_result.at (2)
--			assert ("Expected element [value8,3.9]", l_tuple[1] ~ "value8" and l_tuple[2] ~ "3.9")
-- 			Redis return 3.899999999999999
			l_tuple := l_result.at (3)
			assert ("Expected element [value5,4]", l_tuple[1] ~ "value5" and l_tuple[2] ~ "4")
		end

	test_zrange_withscores_empty
		--ZRANGE key start end 				
		--Return a range of elements from the sorted set at key
		local
			l_result : LIST [TUPLE[detachable STRING,detachable STRING]]
		do
			assert("Expected 1", 1 = redis.zadd ("key", 1, "value1"))
			assert("Expected 1", 1 = redis.zadd ("key", 5, "value2"))
			assert("Expected 1", 1 = redis.zadd ("key", 2, "value3"))
			assert("Expected 1", 1 = redis.zadd ("key", 1.9, "value4"))
			assert("Expected 1", 1 = redis.zadd ("key", 4, "value5"))
			assert("Expected 1", 1 = redis.zadd ("key", 7, "value6"))
			assert("Expected 1", 1 = redis.zadd ("key", 7.9, "value7"))
			assert("Expected 1", 1 = redis.zadd ("key", 3.9, "value8"))
			l_result := redis.zrange_withscores("key",9,10)
			assert ("Expected empty", l_result.is_empty)
		end

	test_zrevrange
		--ZREVRANGE key start end 				
		--Return a range of elements from the sorted set at key, exactly like ZRANGE,
		--but the sorted set is ordered in traversed in reverse order, from the greatest to the smallest score
		local
			l_result : LIST [detachable STRING]
		do
			assert("Expected 1", 1 = redis.zadd ("key", 1, "value1"))
			assert("Expected 1", 1 = redis.zadd ("key", 5, "value2"))
			assert("Expected 1", 1 = redis.zadd ("key", 2, "value3"))
			assert("Expected 1", 1 = redis.zadd ("key", 1.9, "value4"))
			assert("Expected 1", 1 = redis.zadd ("key", 4, "value5"))
			assert("Expected 1", 1 = redis.zadd ("key", 7, "value6"))
			assert("Expected 1", 1 = redis.zadd ("key", 7.9, "value7"))
			assert("Expected 1", 1 = redis.zadd ("key", 3.9, "value8"))
			l_result := redis.zrevrange("key",2,4)
			assert ("Expected element value2", "value2" ~ l_result.at (1))
			assert ("Expected element value5", "value5" ~ l_result.at (2))
			assert ("Expected element value8", "value8" ~ l_result.at (3))
		end

	test_zrevrange_withscores
		--ZRANGE key start end 				
		--Return a range of elements from the sorted set at key
		local
			l_result : LIST [TUPLE[detachable STRING,detachable STRING]]
			l_tuple : TUPLE[detachable STRING,detachable STRING]
		do
			assert("Expected 1", 1 = redis.zadd ("key", 1, "value1"))
			assert("Expected 1", 1 = redis.zadd ("key", 5, "value2"))
			assert("Expected 1", 1 = redis.zadd ("key", 2, "value3"))
			assert("Expected 1", 1 = redis.zadd ("key", 1.9, "value4"))
			assert("Expected 1", 1 = redis.zadd ("key", 4, "value5"))
			assert("Expected 1", 1 = redis.zadd ("key", 7, "value6"))
			assert("Expected 1", 1 = redis.zadd ("key", 7.9, "value7"))
			assert("Expected 1", 1 = redis.zadd ("key", 3.9, "value8"))
			l_result := redis.zrevrange_withscores("key",2,4)
			l_tuple := l_result.at (1)
			assert ("Expected element [value2,5]", l_tuple[1] ~ "value2" and l_tuple[2]~"5")
			l_tuple := l_result.at (2)
			assert ("Expected element [value5,4]", l_tuple[1] ~ "value5" and l_tuple[2] ~ "4")
			l_tuple := l_result.at (3)
--			assert ("Expected element [value8,3.9]", l_tuple[1] ~ "value8" and l_tuple[2] ~ "3.9")
		end

	test_zrevrange_withscores_empty
		--ZRANGE key start end 				
		--Return a range of elements from the sorted set at key
		local
			l_result : LIST [TUPLE[detachable STRING,detachable STRING]]
		do
			assert("Expected 1", 1 = redis.zadd ("key", 1, "value1"))
			assert("Expected 1", 1 = redis.zadd ("key", 5, "value2"))
			assert("Expected 1", 1 = redis.zadd ("key", 2, "value3"))
			assert("Expected 1", 1 = redis.zadd ("key", 1.9, "value4"))
			assert("Expected 1", 1 = redis.zadd ("key", 4, "value5"))
			assert("Expected 1", 1 = redis.zadd ("key", 7, "value6"))
			assert("Expected 1", 1 = redis.zadd ("key", 7.9, "value7"))
			assert("Expected 1", 1 = redis.zadd ("key", 3.9, "value8"))
			l_result := redis.zrevrange_withscores("key",9,10)
			assert ("Expected empty", l_result.is_empty)
		end


	test_zrangebyscore
		--ZRANGEBYSCORE key min max 				
		--Return all the elements with score >= min and score <= max (a range query) from the sorted set
		local
			l_result : LIST [detachable STRING]
		do
			assert("Expected 1", 1 = redis.zadd ("key", 1, "value1"))
			assert("Expected 1", 1 = redis.zadd ("key", 5, "value2"))
			assert("Expected 1", 1 = redis.zadd ("key", 2, "value3"))
			assert("Expected 1", 1 = redis.zadd ("key", 1.9, "value4"))
			assert("Expected 1", 1 = redis.zadd ("key", 4, "value5"))
			assert("Expected 1", 1 = redis.zadd ("key", 7, "value6"))
			assert("Expected 1", 1 = redis.zadd ("key", 7.9, "value7"))
			assert("Expected 1", 1 = redis.zadd ("key", 3.9, "value8"))
			l_result := redis.zrangebyscore("key",2,4)
			assert ("Expected element value3", "value3" ~ l_result.at (1))
			assert ("Expected element value8", "value8" ~ l_result.at (2))
			assert ("Expected element value5", "value5" ~ l_result.at (3))
		end


	test_zrangebyscore_empty
		--ZRANGEBYSCORE key min max 				
		--Return all the elements with score >= min and score <= max (a range query) from the sorted set
		local
			l_result : LIST [detachable STRING]
		do
			assert("Expected 1", 1 = redis.zadd ("key", 1, "value1"))
			assert("Expected 1", 1 = redis.zadd ("key", 5, "value2"))
			assert("Expected 1", 1 = redis.zadd ("key", 2, "value3"))
			assert("Expected 1", 1 = redis.zadd ("key", 1.9, "value4"))
			assert("Expected 1", 1 = redis.zadd ("key", 4, "value5"))
			assert("Expected 1", 1 = redis.zadd ("key", 7, "value6"))
			assert("Expected 1", 1 = redis.zadd ("key", 7.9, "value7"))
			assert("Expected 1", 1 = redis.zadd ("key", 3.9, "value8"))
			l_result := redis.zrangebyscore("key",4,2)
			assert("Expected empty", l_result.is_empty)
		end

	test_zcount
		--ZCOUNT key min max 				
		--Return the number of elements with score >= min and score <= max in the sorted set
		do
			assert("Expected 1", 1 = redis.zadd ("key", 1, "value1"))
			assert("Expected 1", 1 = redis.zadd ("key", 5, "value2"))
			assert("Expected 1", 1 = redis.zadd ("key", 2, "value3"))
			assert("Expected 1", 1 = redis.zadd ("key", 1.9, "value4"))
			assert("Expected 1", 1 = redis.zadd ("key", 4, "value5"))
			assert("Expected 1", 1 = redis.zadd ("key", 7, "value6"))
			assert("Expected 1", 1 = redis.zadd ("key", 7.9, "value7"))
			assert("Expected 1", 1 = redis.zadd ("key", 3.9, "value8"))
			assert("Expected 4", 4 = redis.zcount("key",1.5,4))
		end

	test_zcount_empty
		do
			assert("Expected 0", 0 = redis.zcount("key",8,9))
		end

	test_zcard_empty
		--ZCARD key
		--Return the cardinality (number of elements) of the sorted set at key
		do
			assert("Expected 0", 0 = redis.zcard ("key"))
		end

	test_zcard
		do
			assert("Expected 1", 1 = redis.zadd ("key", 1, "value1"))
			assert("Expected 1", 1 = redis.zadd ("key", 5, "value2"))
			assert("Expected 1", 1 = redis.zadd ("key", 2, "value3"))
			assert("Expected 1", 1 = redis.zadd ("key", 1.9, "value4"))
			assert("Expected 1", 1 = redis.zadd ("key", 4, "value5"))
			assert("Expected 1", 1 = redis.zadd ("key", 7, "value6"))
			assert("Expected 1", 1 = redis.zadd ("key", 7.9, "value7"))
			assert("Expected 1", 1 = redis.zadd ("key", 3.9, "value8"))
			assert("Expected 4", 8 = redis.zcard("key"))
		end

	test_zscore_empty
		--ZSCORE key element 				
		--Return the score associated with the specified element of the sorted set at key
		do
			assert("Expected Void", Void = redis.zscore("key","element"))
		end

	test_zcore
		do
			assert("Expected 1", 1 = redis.zadd ("key", 1.5, "value1"))
			assert("Expected 1.5", "1.5" ~ redis.zscore("key","value1"))
		end

	test_zremrangebyrank
		--ZREMRANGEBYRANK 	key min max 				
		--Remove all the elements with rank >= min and rank <= max from the sorted set
		do
			assert("Expected 1", 1 = redis.zadd ("key", 1, "value1"))
			assert("Expected 1", 1 = redis.zadd ("key", 5, "value2"))
			assert("Expected 1", 1 = redis.zadd ("key", 2, "value3"))
			assert("Expected 1", 1 = redis.zadd ("key", 1.9, "value4"))
			assert("Expected 1", 1 = redis.zadd ("key", 4, "value5"))
			assert("Expected 1", 1 = redis.zadd ("key", 7, "value6"))
			assert("Expected 1", 1 = redis.zadd ("key", 7.9, "value7"))
			assert("Expected 1", 1 = redis.zadd ("key", 3.9, "value8"))
			assert("Expected 2", 2 = redis.zremrangebyrank ("key",1,2))
		end

	test_zremrangebyrank_empty
		--ZREMRANGEBYRANK 	key min max 				
		--Remove all the elements with rank >= min and rank <= max from the sorted set
		do
			assert("Expected 0", 0 = redis.zremrangebyrank ("key",1,2))
		end

	test_zremrangebyscore
		--ZREMRANGEBYSCORE 	key min max 				
		--Remove all the elements with score >= min and score <= max from the sorted set	
		do
			assert("Expected 1", 1 = redis.zadd ("key", 1, "value1"))
			assert("Expected 1", 1 = redis.zadd ("key", 5, "value2"))
			assert("Expected 1", 1 = redis.zadd ("key", 2, "value3"))
			assert("Expected 1", 1 = redis.zadd ("key", 1.9, "value4"))
			assert("Expected 1", 1 = redis.zadd ("key", 4, "value5"))
			assert("Expected 1", 1 = redis.zadd ("key", 7, "value6"))
			assert("Expected 1", 1 = redis.zadd ("key", 7.9, "value7"))
			assert("Expected 1", 1 = redis.zadd ("key", 3.9, "value8"))
			assert("Expected 2", 2 = redis.zremrangebyscore ("key",0.8,1.9))
		end

	test_zremrangebyscore_empty
		--ZREMRANGEBYSCORE 	key min max 				
		--Remove all the elements with score >= min and score <= max from the sorted set	
		do
			assert("Expected 0", 0 = redis.zremrangebyscore ("key",1.3,2))
		end

	test_zunionstore
		--ZUNIONSTORE dstkey N k1 ... kN [WEIGHTS w1 ... wN] [AGGREGATE SUM|MIN|MAX]		
		--Perform a union or intersection over a number of sorted sets with optional weight and aggregate
		do
			assert("Expected 1", 1 = redis.zadd ("key1", 1, "value1"))
			assert("Expected 1", 1 = redis.zadd ("key2", 5, "value2"))
			assert("Expected 1", 1 = redis.zadd ("key3", 2, "value3"))

			assert("expected 3", 3 = redis.zunionstore("u",<<"key1","key2","key3">>))
			assert("Expected 1", 1 = redis.zadd ("key4", 2, "value3"))
			assert("expected 3", 3 = redis.zunionstore("u",<<"key1","key2","key3","key4">>))
		end

	test_zinterstore
		--ZINTERSTORE dstkey N k1 ... kN [WEIGHTS w1 ... wN] [AGGREGATE SUM|MIN|MAX]		
		--Perform a union or intersection over a number of sorted sets with optional weight and aggregate
		do
			assert("Expected 1", 1 = redis.zadd ("key1", 1, "value1"))
			assert("Expected 1", 1 = redis.zadd ("key2", 5, "value2"))
			assert("Expected 1", 1 = redis.zadd ("key3", 2, "value3"))

			assert("expected 0", 0 = redis.zinterstore("u",<<"key1","key2","key3">>))
			assert("Expected 1", 1 = redis.zadd ("key4", 2, "value3"))
			assert("expected 1", 1= redis.zunionstore("u",<<"key3","key4">>))
		end
feature -- testing status report

feature -- testing hsets
	test_hset
		--HSET key field value 				
		--Set the hash field to the specified value. Creates the hash if needed.
		do
			assert ("Expected 1", 1 = redis.hset("key","field","value"))
			assert ("Expected 0", 0 = redis.hset("key","field","value1"))
		end

	test_hget_empty
		--HGET key field 					
		--Retrieve the value of the specified hash field.
		do
			assert("Expected void", Void = redis.hget("key","field"))
		end

	test_hget
		--HGET key field 					
		--Retrieve the value of the specified hash field.
		do
			assert ("Expected 1", 1 = redis.hset("key","field","value"))
			assert("Expected value", "value" ~ redis.hget("key","field"))
		end

	test_hsetnx
		--HSETNX key field value 				
		do
			assert ("Expected 1", 1 = redis.hsetnx ("k","f","v"))
			assert ("Expected 0", 0 = redis.hsetnx ("k","f","v1"))
			assert ("Expected v", "v" ~ redis.hget ("k", "f"))
		end

	test_hmset
		--HMSET	 key field1 value1 ... fieldN valueN 		
		--Set the hash fields to their respective values.	
		local
			l_field_values : HASH_TABLE[STRING,STRING]
		do
			create l_field_values.make (4)
			l_field_values.put ("v", "f")
			l_field_values.put ("v1", "f1")
			l_field_values.put ("v2", "f2")
			l_field_values.put ("v3", "f3")
			redis.hmset("k",l_field_values)
			assert ("Expected value v", "v" ~ redis.hget ("k", "f"))
			assert ("Expected value v1", "v1" ~ redis.hget ("k", "f1"))
			assert ("Expected value v2", "v2" ~ redis.hget ("k", "f2"))
			assert ("Expected value v3", "v3" ~ redis.hget ("k", "f3"))
		end

	test_hmget
		--HMGET key field1 ... fieldN
		--Get the hash values associated to the specified fields.
		local
			l_field_values : HASH_TABLE[STRING,STRING]
			l_result : LIST [detachable STRING]
		do
			create l_field_values.make (4)
			l_field_values.put ("v", "f")
			l_field_values.put ("v1", "f1")
			l_field_values.put ("v2", "f2")
			l_field_values.put ("v3", "f3")
			l_result := redis.hmget("k",<<"f","f1","f2","f3">>)
			assert("Expected 4 elements", 4 = l_result.count)
		end

	test_hincrby
		--HINCRBY key field value
		do
			assert("expected 5", 5 = redis.hincrby("k","f",5))
			assert("expected -1", -1 = redis.hincrby("k","f1",-1))
		end

	test_hexists
		--HEXISTS key field
		do
			assert ("Expect false", not redis.hexists ("k","f"))
			assert("expected 5", 5 = redis.hincrby("k","f",5))
			assert ("Expect True", redis.hexists ("k","f"))
		end

	test_hdel
		--HDEL key field	
		do
			assert("Expect 0", 0 = redis.hdel("k","f"))
			assert("Expect 1", 1 = redis.hset ("k", "f", "v"))
			assert("Expect true", redis.hexists ("k","f"))
			assert("Expect 1", 1 = redis.hdel("k","f"))
			assert("Expect false", not redis.hexists ("k","f"))
		end

	test_hlen
		-- HLEN key
		do
			assert ("Expected 0", 0 = redis.hlen ("k"))
			assert("Expect 1", 1 = redis.hset ("k", "f", "v"))
			assert("Expect 1", 1 = redis.hset ("k", "f1", "v"))
			assert("Expect 1", 1 = redis.hset ("k", "f2", "v"))
			assert("Expect 1", 1 = redis.hset ("k", "f3", "v"))
			assert ("Expected 4", 4 = redis.hlen ("k"))
		end


	test_hgetall
		--HGETALL 	key 						
		--Return all the fields and associated values in a hash.
		local
			l_result : LIST[detachable STRING]
		do
			assert("Expect 1", 1 = redis.hset ("k", "f", "v"))
			assert("Expect 1", 1 = redis.hset ("k", "f1", "v"))
			assert("Expect 1", 1 = redis.hset ("k", "f2", "v"))
			assert("Expect 1", 1 = redis.hset ("k", "f3", "v"))
			l_result := redis.hgetall ("k")
			assert ("Expected not void", l_result /= Void)
			assert ("Expected f", l_result.at (1) ~ "f")
			assert ("Expected v", l_result.at (2) ~ "v")
			assert ("Expected len 8", l_result.count = 8)
		end

	test_hgetall_empty
		--HGETALL 	key 						
		--Return all the fields and associated values in a hash.
		local
			l_result : LIST[detachable STRING]
		do
			l_result := redis.hgetall ("k")
			assert ("Expected Empty list", l_result.is_empty)
		end

	test_hkeys
		--HKEYS	key 						
		--Return all the fields in a hash.
		local
			l_result : LIST [detachable STRING]
		do
			assert("Expect 1", 1 = redis.hset ("k", "f", "v"))
			assert("Expect 1", 1 = redis.hset ("k", "f1", "v"))
			assert("Expect 1", 1 = redis.hset ("k", "f2", "v"))
			assert("Expect 1", 1 = redis.hset ("k", "f3", "v"))
			l_result := redis.hkeys ("k")
			assert ("Expected len 4", l_result.count = 4)
			assert ("Expected f", l_result.at (1) ~ "f")
			assert ("Expected f1", l_result.at (2) ~ "f1")
			assert ("Expected f2", l_result.at (3) ~ "f2")
			assert ("Expected f3", l_result.at (4) ~ "f3")
		end


	test_hkeys_empty
		--HKEYS	key 						
		--Return all the fields in a hash.
		local
			l_result : LIST [detachable STRING]
		do
			l_result := redis.hkeys ("k")
			assert ("Expected empty", l_result.is_empty)
		end


	test_hvals
		--HVALS key 						
		--Return all the values in a hash
		local
			l_result : LIST [detachable STRING]
		do
			assert("Expect 1", 1 = redis.hset ("k", "f", "v"))
			assert("Expect 1", 1 = redis.hset ("k", "f1", "v1"))
			assert("Expect 1", 1 = redis.hset ("k", "f2", "v2"))
			assert("Expect 1", 1 = redis.hset ("k", "f3", "v3"))
			l_result := redis.hvals ("k")
			assert ("Expected len 4", l_result.count = 4)
			assert ("Expected v", l_result.at (1) ~ "v")
			assert ("Expected v1", l_result.at (2) ~ "v1")
			assert ("Expected v2", l_result.at (3) ~ "v2")
			assert ("Expected v3", l_result.at (4) ~ "v3")
		end


	test_hvals_empty
		--HVALS key 						
		--Return all the values in a hash
		local
			l_result : LIST [detachable STRING]
		do
			l_result := redis.hvals ("k")
			assert ("Expected empty", l_result.is_empty)
		end

feature -- Remote Server Controls

	test_info
		--INFO 		
		--Provide information and statistics about the server
		do
			assert ("Expected Not Void", redis.info /= Void)
		end


	test_bgrewriteaof
		--BGREWRITEAOF
		--Asynchronously rewrite the append-only file  	
		do
			redis.bgrewriteaof
			assert ("Expected has not error", not redis.has_error)
		end

	test_bgsave
		--BGSAVE
		--Asynchronously save the dataset to disk
		do
			redis.bgsave
			assert ("Expected has not error", not redis.has_error)
		end

	test_config_get_all
		--CONFIG GET   parameter
		--Get the value of a configuration parameter  	
		local
			l_result : LIST [detachable STRING]
		do
			l_result := redis.config_get ("*")
			assert("Expected 98 elements", l_result.count = 98)
		end

	test_config_get_maxmemory
		--CONFIG GET   parameter
		--Get the value of a configuration parameter  	
		local
			l_result : LIST [detachable STRING]
		do
			l_result := redis.config_get (maxmemory)
			assert("Expected 2 elements", l_result.count = 2)
			assert("Expected maxmemory",  l_result.at (1) ~ maxmemory)
			assert("Expected >= 0",  l_result.at (2).to_integer_64 >= 0)
		end


	test_config_get_paramater_does_not_exists_should_be_empty
		--CONFIG GET   parameter
		--Get the value of a configuration parameter  	
		local
			l_result : LIST [detachable STRING]
		do
			l_result := redis.config_get ("notexists")
			assert("Expected empty", l_result.is_empty)
		end


	test_config_set
		-- CONFIG SET   parameter value
		-- Set a configuration parameter to the given value
		local
			l_result : LIST [detachable STRING]
		do
			redis.config_set ( maxmemory, "10")
			l_result := redis.config_get (maxmemory)
			assert ("Expected 10", l_result.at (2).to_integer_64 = 10)

			redis.config_set ( maxmemory, "0")
			l_result := redis.config_get (maxmemory)
			assert ("Expected 0", l_result.at (2).to_integer_64 = 0)
		end


	test_config_set_wrong
		-- CONFIG SET   parameter value
		-- Set a configuration parameter to the given value
		do
			redis.config_set ( "notexist", "10")
			assert("Expected error", redis.has_error)
		end

	test_config_resetstat
		--CONFIG RESETSTAT
		--Reset the stats returned by INFO  	
		do
			redis.config_resetstat
			assert("Expected not error", not redis.has_error)
		end

	test_debug_object
		--DEBUG OBJECT key
		--Get debugging information about a key
		local
			l_result : STRING
		do
			redis.set ("k", "v")
			l_result := redis.debug_object ("k")
			assert ("Expected not empty", not l_result.is_empty)
		end

--	test_debug_segfault
--		--DEBUG SEGFAULT
--		--Make the server crash  	
--		do
--			redis.debug_segfault
--			assert("Expected not error", not redis.has_error)
--		end

	test_lastsave
		--LASTSAVE
		--Get the UNIX time stamp of the last successful save to disk
		do
			assert ("Expected greater than cero", redis.lastsave >= 0)
		end

	test_monitor
		--MONITOR
		--Listen for all requests received by the server in real time
		do

		end

	test_save
		--SAVE
		--Synchronously save the dataset to disk
		do
			redis.save
			assert("Expected not error", not redis.has_error)
		end


--	test_shutdown
--		--SHUTDOWN
--		--Synchronously save the dataset to disk and then shut down the server
--		do
--			redis.shutdown
--			assert("Expected not error", not redis.has_error)
--		end

	test_slaveof
		--SLAVEOF   host port
		--Make the server a slave of another instance, or promote it as master
		do
			redis.slaveof (host, port)
			assert("Expected not error", not redis.has_error)
		end

	test_sync
		--SYNC
		--Internal command used for replication  	
		do

		end

feature {NONE} -- Implemention
	port : INTEGER = 6379
	host : STRING =  "127.0.0.1"
end


