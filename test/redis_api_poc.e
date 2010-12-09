note
	description: "{REDIS_API} for Redis 2.x protocol"
	author: "Javier Velilla"
	date: "$Date$"
	revision: "$Revision$"

class
	REDIS_API_POC

create
	make,
	make_client_by_port
feature -- Initialization
	make_client_by_port (a_port : INTEGER; a_host:STRING)
		require
			valid_host: a_host /= Void
		do
			create socket.make_client_by_port (default_peer_port, a_host)
			socket.connect
		ensure
			is_connected : socket.is_connected
		end

	make
		-- Create an instance and make a connection to redis
		-- in the default port "localhost:6379"
		do
			create socket.make_client_by_port (default_peer_port, default_peer_host)
			socket.connect
		ensure
			is_connected : socket.is_connected
		end
feature {NONE} -- Implementation
	socket : NETWORK_STREAM_SOCKET
		-- connection to redis


feature -- Commands
	SET_Command			: STRING = "SET"
	GET_Command			: STRING = "GET"
	MGET_Command		: STRING = "MGET"
	MSET_Command		: STRING = "MSET"
	Flush_db_command	: STRING = "FLUSHDB"
	Flush_all_command	: STRING = "FLUSHALL"
	Exists_command		: STRING = "EXISTS"
	DEL_Command			: STRING = "DEL"
	TYPE_Command		: STRING = "TYPE"
	KEYS_Command		: STRING = "KEYS"
	RENAME_Command		: STRING = "RENAME"
	DBSIZE_Command		: STRING = "DBSIZE"
	SELECT_Command		: STRING = "SELECT"
	QUIT_Command		: STRING = "QUIT"
	TTL_Command			: STRING = "TTL"
	EXPIRE_Command		: STRING = "EXPIRE"
	PERSIST_Command		: STRING = "PERSIST" -- actually not supported
	MOVE_Command		: STRING = "MOVE"
	RPUSH_Command		: STRING = "RPUSH"
	LPUSH_Command		: STRING = "LPUSH"
	LLEN_Command		: STRING = "LLEN"
	LRANGE_Command		: STRING = "LRANGE"
	LTRIM_Command		: STRING = "LTRIM"
	LINDEX_Command		: STRING = "LINDEX"
	LSET_Command		: STRING = "LSET"
	LREM_Command		: STRING = "LREM"
	LPOP_Command		: STRING = "LPOP"
	RPOP_Command		: STRING = "RPOP"
	SADD_Command		: STRING = "SADD"
	SREM_Command		: STRING = "SREM"
	SPOP_Command		: STRING = "SPOP"
	SCARD_Command		: STRING = "SCARD"
	SISMEMBER_Command	: STRING = "SISMEMBER"
	SINTER_Command		: STRING = "SINTER"
	SMOVE_Command		: STRING = "SMOVE"
	SINTERSTORE_Command	: STRING = "SINTERSTORE"
	SUNION_Command		: STRING = "SUNION"
	SUNIONSTORE_Command	: STRING = "SUNIONSTORE"
	SDIFF_Command		: STRING = "SDIFF"
	SDIFFSTORE_Command	: STRING = "SDIFFSTORE"
	SMEMBERS_Command	: STRING = "SMEMBERS"
	SRANDMEMBER_Command : STRING = "SRANDMEMBER"

	Redis_commands : ARRAY[STRING]
		-- List of valid redis commands
		once
			Result :=<<set_command,get_command,mget_command,mset_command,flush_db_command,flush_all_command,exists_command,del_command,
				type_command, keys_command, rename_command,dbsize_command,select_command,quit_command,ttl_command,expire_command,
				persist_command, move_command,rpush_command,lpush_command,llen_command,lrange_command,ltrim_command,lindex_command,
				lset_command,lrem_command,rpop_command,lpop_command,sadd_command,srem_command,spop_command,scard_command,sismember_command,
				sinter_command,smove_command,sinterstore_command,sunion_command,sunionstore_command,sdiff_command,sdiffstore_command,
				smembers_command,srandmember_command>>
		end

	TYPE_NONE : STRING = "none"
			-- 	"none" if the key does not exist
	TYPE_STRING  : STRING = "string"
			--"string" if the key contains a String value
	TYPE_LIST : STRING = "list"
			--"list" if the key contains a List value
	TYPE_SET :	STRING = "set"
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

	read_status_reply : STRING
		-- Replies are single line
		-- "+.." SUCCESS
		-- "-.." ERROR
		require
			is_connected : is_connected
		do
			socket.read_line_thread_aware
			Result := socket.last_string
		end

	read_integer_reply : INTEGER
		require
			is_connected: is_connected
		local
			l_result : STRING
		do
			socket.read_line_thread_aware
			l_result := socket.last_string
			Result := l_result.substring (2, l_result.count -1).to_integer
		end

	read_bulk_reply : STRING
		--A bulk reply is a binary-safe reply that is used to return a binary safe single string value
		--(string is not limited to alphanumerical strings, it may contain binary data of any kind).
		--Client libraries will usually return a string as return value of Redis commands returning bulk replies.
		--There is a special bulk reply that signal that the element does not exist.
		--When this happens the client library should return 'nil', 'false',
		--or some other special element that can be distinguished by an empty string.
		local
			l_string: STRING
			l_bytes : INTEGER
		do
			socket.read_line_thread_aware
			l_string :=  socket.last_string
			if not  l_string.has_substring (null_response) then
				l_bytes := (l_string.substring (2, l_string.count - 1)).to_integer
				socket.read_stream_thread_aware (l_bytes)
				Result := socket.last_string
				socket.read_line_thread_aware
			end
		end

	read_multi_bulk_reply : LIST[STRING]
		--While a bulk reply returns a single string value,
		--multi bulk replies are used to return multiple values: lists, sets, and so on.
		--Elements of a bulk reply can be missing.
		--Client libraries should return 'nil' or 'false' in order to make this elements distinguishable from empty strings.
		--Client libraries should return multi bulk replies that are about ordered elements like list ranges as lists,
		-- and bulk replies about sets as hashes or Sets if the implementation language has a Set type.
		local
			l_string: STRING
			l_bytes : INTEGER
			l_return : ARRAYED_LIST[STRING]
		do
			-- TODO clean this code
			create l_return.make (10)
			socket.read_line_thread_aware
			l_string := socket.last_string
			if l_string.has_substring (not_exist_key) then
				l_bytes := (l_string.substring (2, l_string.count - 1)).to_integer
				print("The server return ["+ l_bytes.out + "] responses")
			else
				from
				until
					not socket.is_readable
				loop
					socket.read_line_thread_aware
					l_string := socket.last_string
					if not  l_string.has_substring (null_response) then
						l_bytes := (l_string.substring (2, l_string.count - 1)).to_integer
						socket.read_stream_thread_aware (l_bytes)
						l_return.force (socket.last_string)
						socket.read_line_thread_aware
					else
						l_return.force (Void)
					end
				end
			end
			Result := l_return
		end

	full_message : STRING
		-- Full error message	

	check_reply ( a_reply : STRING )
		--Check the single line reply
		-- If the reply contains as first character "+", is OK
		-- If the reply contains as first character "-", is ERROR	
		do
			if a_reply.at (1).is_equal (minus_byte) then
				has_error := true
				full_message := "There was an error: {" + a_reply + "}"
			end
		end

	send_command ( a_command : STRING; arguments :LIST[STRING])
		require
			is_valid_command :is_valid_redis_command (a_command)
			is_connnected : is_connected
		do

			socket.put_string (asterisk_byte.out+(arguments.count+1).out + crlf)
			socket.put_string (dollar_byte.out+ a_command.count.out + crlf)
			socket.put_string (a_command + crlf)
			from
				arguments.start
			until
				arguments.after
			loop
				socket.put_string (dollar_byte.out+arguments.item_for_iteration.count.out+crlf)
				socket.put_string (arguments.item_for_iteration+crlf)
				arguments.forth
			end
		end


feature -- Close Connection
	close
		-- Close the connection
		require
			connected :is_connected
		do
			quit
			socket.close
			check
			socket.is_closed
			end
		ensure
			not_connected : socket.is_closed
		end

feature -- Status Report

	is_valid_redis_command (a_command : STRING) : BOOLEAN
		require
			not_void : a_command /= Void
		do
			Result := redis_commands.has (a_command)
		end

	is_valid_redis_type ( a_type : STRING) : BOOLEAN
		require
			not_void : a_type /= Void
		do
			redis_types.compare_objects
			Result := redis_types.has (a_type)
		end

	has_error : BOOLEAN
		-- Did an error occur?

	is_connected :  BOOLEAN
		-- Is the socket connection connected?
		do
			Result := socket.is_connected
		end

	error_description : STRING
		-- Error description
		require
		   has_error : has_error
		do
			Result := full_message
		end

	clean_error
		-- Remove the last error
		do
			has_error := False
			full_message := Void
		ensure
			not_has_error : not has_error
			not_message   : full_message = Void
		end
feature -- Redis Connection Handling
	quit
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (0)
			send_command (quit_command, l_arguments)
		end

feature -- Redis Commands operating on all value types

	exists (a_key : STRING) : BOOLEAN
		-- Test if the specified key exists.
		-- The command returns `True' if the key exists, otherwise `False' is returned.
		require
			valid_key : a_key /= Void
		local
			l_arguments : ARRAYED_LIST[STRING]
			l_result : INTEGER
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (exists_command, l_arguments)
			l_result := read_integer_reply
			if l_result = 1 then
				Result := True
			end
		end

	persist (a_key : STRING)
		-- remove the expire from a key
		-- currently not supported
		require
			valid_key : a_key /= Void
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (persist_command, l_arguments)

		end

	del (arguments : ARRAY[STRING]) : INTEGER
		-- Remove the specified keys.
		-- If a given key does not exist no operation is performed for this key
		-- The command returns the number of keys removed.
		require
			valid_arguments : arguments /= Void
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make_from_array (arguments)
			send_command (del_command, l_arguments)
			Result := read_integer_reply
		end

	type (a_key : STRING ) : STRING
		-- Return the type of the value stored at key in form of a string.
		-- The type can be one of "none", "string", "list", "set". "none" is returned if the key does not exist.
		require
			valid_key : a_key /= Void
		local
			l_arguments : ARRAYED_LIST[STRING]
			l_result : STRING
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (type_command, l_arguments)
			l_result := read_status_reply
			Result := l_result.substring (2, l_result.count - 1)
		ensure
			is_valid_type: is_valid_redis_type (Result)
		end

	rename_key ( an_old_key : STRING; a_new_key : STRING)
		-- Atomically renames the key `an_old_key' to `a_new_key'.
		-- If the source and destination name are the same an error is returned.
		-- If newkey already exists it is overwritten.
		require
			valid_keys : an_old_key /= Void and then a_new_key /= Void
			not_equals : not (an_old_key ~ a_new_key)
		local
			l_arguments : ARRAYED_LIST[STRING]
			reply : STRING
		do
			create l_arguments.make (2)
			l_arguments.force (an_old_key)
			l_arguments.force (a_new_key)
			send_command (rename_command,l_arguments)
			reply := read_status_reply
			check_reply (reply)
		end
	keys ( a_pattern : STRING) : LIST[STRING]
		-- Returns all the keys matching the glob-style pattern as space separated strings.
		require
			valid_pattern : a_pattern /= Void
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_pattern)
			send_command (keys_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	db_size: INTEGER
		-- Return the number of keys in the currently selected database.
		require
			is_connected : is_connected
		local
			l_arguments: ARRAYED_LIST[STRING]
		do
			create l_arguments.make (0)
			send_command (dbsize_command, l_arguments)
			Result := read_integer_reply
		end

	select_db ( an_index : INTEGER)
		-- Select the DB with having the specified zero-based numeric index.
		-- For default every new client connection is automatically selected to DB 0. 	
		local
			l_arguments : ARRAYED_LIST[STRING]
			reply : STRING
		do
			create l_arguments.make (1)
			l_arguments.force (an_index.out)
			send_command (select_command,l_arguments)
			reply := read_status_reply
			check_reply (reply)
		end

	expire (a_key : STRING; a_seconds : INTEGER)
		-- set a time to live in seconds `a_seconds' on a key `a_key'
		require
			valid_key : a_key /= Void
			valid_timeout : a_seconds > 0
		local
			l_arguments : ARRAYED_LIST[STRING]
			l_result : INTEGER
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_seconds.out)
			send_command (expire_command, l_arguments)
			l_result := read_integer_reply
			-- TODO Log the result
		end

	ttl (a_key : STRING) : INTEGER
		-- The TTL command returns the remaining time to live in seconds of a key that has an EXPIRE set.
		-- This introspection capability allows a Redis client to check how many seconds a given key will continue to be part of the dataset.
		-- If the Key does not exists or does not have an associated expire, -1 is returned.
		require
			valid_key : a_key /= Void
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (ttl_command, l_arguments)
			Result := read_integer_reply
		ensure
			valid_return : Result >= -1
		end

	move (a_key : STRING ; an_index : INTEGER)
		-- Move the specified key from the currently selected DB to the specifieddestination DB.
		-- Note that this command returns 1 only if the key was successfully moved, and 0 if the target key was already there
		-- or if the source key was not found at all, so it is possible to use MOVE as a locking primitive.
		require
			valid_key : a_key /= Void
			valid_index : an_index >= 0
		local
			l_arguments : ARRAYED_LIST[STRING]
			l_result : INTEGER
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (an_index.out)
			send_command (move_command, l_arguments)
			l_result := read_integer_reply
			-- TODO log the l_result
			check
				l_result >= 0
			end
		end

	flush_db
		-- Delete all the keys of the currently selected DB.
		require
			is_connected : is_connected
		local
			l_arguments : ARRAYED_LIST[STRING]
			reply : STRING
		do
			create l_arguments.make (0)
			send_command (flush_db_command, l_arguments)
			reply := read_status_reply
			check_reply (reply)
		end

	flush_all
		-- Delete all the keys of all the existing databases, not just the currently selected one.
		require
			is_connected : is_connected
		local
			l_arguments : ARRAYED_LIST[STRING]
			reply : STRING
		do
			create l_arguments.make (0)
			send_command (flush_all_command, l_arguments)
			reply := read_status_reply
			check_reply (reply)
		end
feature -- Redis Commands Operating on Strings

	last_reply : STRING
		-- Last simple reply from Redis

	set ( a_key : STRING; a_value : STRING)
		-- SET key value Set a key to a string value
		-- The string can't be longer than 1073741824 bytes
		require
			valid_key: a_key /= Void
			valid_value : a_value /= Void and then a_value.count <= 1073741824
		local
			l_arguments : ARRAYED_LIST[STRING]
			reply : STRING
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_value)
			send_command (set_command, l_arguments)
			reply := read_status_reply
			check_reply (reply)
		ensure
			correct : not has_error
			--if a_key does not exists implies the db has one more element
		end

	mset ( a_params : HASH_TABLE[STRING,STRING])
		   --Set the the respective keys to the respective values.
		   --MSET will replace old values with new values
   		   --MSET is an atomic operation.
   		   require
   		   	valid_param : a_params /= Void
   		   	-- each param should be a valid key and a valid value
   		   	local
   		   		l_arguments : ARRAYED_LIST [STRING]
   		   		reply : STRING
   		   	do
   		   		create l_arguments.make (10)
   		   		from
   		   			a_params.start
   		   		until
   		   			a_params.after
   		   		loop
   		   			l_arguments.force (a_params.key_for_iteration)
   		   			l_arguments.force (a_params.item_for_iteration)
   		   			a_params.forth
   		   		end
   		   		send_command (mset_command, l_arguments)
				reply := read_status_reply
				check_reply (reply)
   		   	end

	get (a_key : STRING) : STRING
		-- Get the value of the specified key.
		-- If the key does not exist the special value 'Void' is returned.
		-- If the value stored at key is not a string an error is returned because GET can only handle string values.
		require
			valid_key : a_key /= Void
			if_the_key_exists_is_string : exists(a_key) implies (type (a_key) ~ type_string)
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (get_command, l_arguments)
			Result := read_bulk_reply
		end


	mget ( a_key : ARRAY[STRING] ) : LIST[STRING]
		---Multi-get, return the strings values of the keys
		require
			valid_keys : a_key /= Void and then not a_key.is_empty
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make_from_array (a_key)
			send_command (mget_command, l_arguments)
			Result := read_multi_bulk_reply
		end

feature -- Redis Commands Operating on Lists

	rpush (a_key : STRING; a_value : STRING):INTEGER
		-- Time complexity: O(1)
		-- Add the string value to the tail (RPUSH) of the liststored at key.
		-- If the key does not exist an empty list is created just beforethe append operation.
		-- If the key exists but is not a List an error is returned.
		require
			valid_key : a_key /= Void
			valid_value : a_value /= Void
			if_exists_key_is_type_list : exists (a_key) implies (type (a_key) ~ type_list)
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_value)
			send_command (rpush_command, l_arguments)
			Result := read_integer_reply
		ensure
			valid_response : Result >= 0
			one_more_element : old(llen (a_key)) + 1  = llen (a_key)
		end


	lpush (a_key : STRING; a_value : STRING):INTEGER
		-- Time complexity: O(1)
		-- Add the string `a_value' to the head (LPUSH) of the list stored at `a_key'.
		-- If the `a_key' does not exist an empty list is created just before the append operation.
		-- If the `a_key' exists but is not a List an error is returned.
		require
			valid_key : a_key /= Void
			valid_value : a_value /= Void
			if_exists_key_is_type_list : exists (a_key) implies (type (a_key) ~ type_list)
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_value)
			send_command (lpush_command, l_arguments)
			Result := read_integer_reply
		ensure
			valid_response : Result >= 0
			one_more_element : old(llen (a_key)) + 1  = llen (a_key)
		end

	llen (a_key : STRING) : INTEGER
		-- Time complexity: O(1)
		-- Return the length of the list stored at the specified `a_key'.
		-- If the `a_key' does not exist zero is returned (the same behaviour as for empty lists).
		-- If the value stored at `a_key' is not a list an error is returned.
		require
			valid_key : a_key /= Void
			if_exists_key_is_type_list : exists (a_key) implies (type (a_key) ~ type_list)
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (llen_command, l_arguments)
			Result := read_integer_reply
		ensure
			valid_result : Result >= 0
		end

	lrange (a_key : STRING; an_start : INTEGER; an_end: INTEGER) : LIST [STRING]
		--Time complexity: O(start+n) (with n being the length of the range and start being the start offset)
		--Return the specified elements of the list stored at the specified key. Start and end are zero-based indexes.
		--0 is the first element of the list (the list head), 1 the next element and so on.	
		--For example LRANGE foobar 0 2 will return the first three elements of the list.
		--start and end can also be negative numbers indicating offsets from the end of the list.
		--For example -1 is the last element of the list, -2 the penultimate element and so on.
		require
			valid_key : a_key /= Void
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (an_start.out)
			l_arguments.force (an_end.out)
			send_command (lrange_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	ltrim (a_key : STRING; an_start : INTEGER; an_end: INTEGER)
		--Time complexity: O(n) (with n being len of list - len of range)
	    --Trim an existing list so that it will contain only the specified range of elements specified.
	    --Start and end are zero-based indexes.
	    --0 is the first element of the list (the list head), 1 the next element and so on.
	    --For example LTRIM foobar 0 2 will modify the list stored at foobar key so that only the first three elements
	    --of the list will remain.
    	--start and end can also be negative numbers indicating offsets from the end of the list.
    	--For example -1 is the last element of the list, -2 the penultimate element and so on.
    	--Indexes out of range will not produce an error:
    	--if start is over the end of the list, or start > end, an empty list is left as value.
    	--If end over the end of the list Redis will threat it just like the last element of the list.
		require
			valid_key : a_key /= Void
		local
			l_arguments : ARRAYED_LIST[STRING]
			l_reply : STRING
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (an_start.out)
			l_arguments.force (an_end.out)
			send_command (ltrim_command, l_arguments)
			l_reply := read_status_reply
			check_reply (l_reply)
		ensure
			valid_status : not has_error
		end


	lindex (a_key : STRING; an_index:INTEGER):STRING
		--Time complexity: O(n) (with n being the length of the list)
		--Return the specified element of the list stored at the specified key.
		--0 is the first element, 1 the second and so on.
		--Negative indexes are supported, for example -1 is the last element, -2 the penultimate and so on.
		--If the value stored at key is not of list type an error is returned.
		--If the index is out of range a 'nil' reply is returned.
		--Note that even if the average time complexity is O(n) asking for the first or the last element of the list is O(1).
		require
			valid_key : a_key /= Void
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (an_index.out)
			send_command (lindex_command, l_arguments)
			Result := read_bulk_reply
		end


	lset (a_key : STRING; an_index:INTEGER; a_value:STRING)
		-- Time complexity: O(N) (with N being the length of the list)
	    -- Set the list element at index (see LINDEX for information about the index argument) with the new value.
	    -- Out of range indexes will generate an error. Note that setting the first or last elements of the list is O(1).
		-- Similarly to other list commands accepting indexes, the index can be negative to access elements starting from the end of the list.
		-- So -1 is the last element, -2 is the penultimate, and so forth.
		require
			valid_key : a_key /= Void
			valid_value  : a_value /= Void
		local
			l_arguments : ARRAYED_LIST[STRING]
			l_reply : STRING
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (an_index.out)
			l_arguments.force (a_value)
			send_command (lset_command, l_arguments)
			l_reply := read_status_reply
			check_reply (l_reply)
		end



	lrem (a_key : STRING; a_count:INTEGER; a_value:STRING):INTEGER
		require
			valid_key : a_key /= Void
			valid_value  : a_value /= Void
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (a_count.out)
			l_arguments.force (a_value)
			send_command (lrem_command, l_arguments)
			Result := read_integer_reply
		ensure
			valid_response : Result >= 0
		end


	lpop (a_key : STRING) : STRING
		--Time complexity: O(1)
    	--Atomically return and remove the first (LPOP)  element of the list.
    	--For example if the list contains the elements "a","b","c" LPOP will return "a" and the list will become "b","c".
	    --If the key does not exist or the list is already empty the special value 'nil' is returned.
		require
			valid_key : a_key /= Void
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (lpop_command, l_arguments)
			Result := read_bulk_reply
		end

	rpop (a_key : STRING) : STRING
		--Time complexity: O(1)
    	--Atomically return and remove the last (RPOP)  element of the list.
    	--For example if the list contains the elements "a","b","c" RPOP will return "c" and the list will become "a","b".
	    --If the key does not exist or the list is already empty the special value 'nil' is returned.
		require
			valid_key : a_key /= Void
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (rpop_command, l_arguments)
			Result := read_bulk_reply
		end

feature -- Redis Commands Operating on Sets		
	sadd,set_add(a_key : STRING; a_member :STRING) : INTEGER
		--Time complexity O(1)
		-- Add the specified member to the set value stored at key.
		-- If member is already a member of the set no operation is performed.
		-- If key does not exist a new set with the specified member as sole member is created.
		-- If the key exists but does not hold a set value an error is returned.
		require
			valid_key : a_key /= Void
			valid_membe : a_member /= Void
			if_exists_key_is_type_set : exists (a_key) implies (type (a_key) ~ type_set)
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_member)
			send_command (sadd_command, l_arguments)
			Result := read_integer_reply
		ensure
			valid_response : Result >= 0
		end


	srem,set_remove(a_key : STRING; a_member :STRING) : INTEGER
		-- Time complexity O(1)
		-- Remove the specified member from the set value stored at key.
		-- If member was not a member of the set no operation is performed.
		-- If key does not hold a set value an error is returned.
		require
			valid_key : a_key /= Void
			valid_membe : a_member /= Void
			if_exists_key_is_type_set : exists (a_key) implies (type (a_key) ~ type_set)
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_member)
			send_command (srem_command, l_arguments)
			Result := read_integer_reply
		ensure
			valid_response : Result >= 0
		end


	spop,set_pop(a_key : STRING) : STRING
		--	Time complexity O(1)
		--  Remove a random element from a Set returning it as return value.
		--  If the Set is empty or the key does not exist, a nil object is returned.
	    -- 	The SRANDMEMBER command does a similar work but the returned element is not removed from the Set.
		require
			valid_key : a_key /= Void
			if_exists_key_is_type_set : exists (a_key) implies (type (a_key) ~ type_set)
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (spop_command, l_arguments)
			Result := read_bulk_reply
		end


	scard,set_cardinality(a_key : STRING) : INTEGER
		-- Time complexity O(1)
	    -- Return the set cardinality (number of elements).
	    -- If the key does not exist 0 is returned, like for empty sets.
		require
			valid_key : a_key /= Void
			if_exists_key_is_type_set : exists (a_key) implies (type (a_key) ~ type_set)
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (scard_command, l_arguments)
			Result := read_integer_reply
		ensure
			valid_response : Result >= 0
		end

	sismember,set_is_member(a_key : STRING; a_value:STRING) : BOOLEAN
		require
			valid_key : a_key /= Void
			valid_value: a_value /= Void
			if_exists_key_is_type_set : exists (a_key) implies (type (a_key) ~ type_set)
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_value)
			send_command (sismember_command, l_arguments)
			Result := (read_integer_reply = 1)
		end

	sinter (arguments : ARRAY[STRING]) : LIST[STRING]
		--Time complexity O(N*M) worst case where N is the cardinality of the smallest set and M the number of sets
		--Return the members of a set resulting from the intersection of all the sets hold at the specified keys.
		-- Like in LRANGE the result is sent to the client as a multi-bulk reply (see the protocol specification for more information).
		-- If just a single key is specified, then this command produces the same result as SMEMBERS.
		-- Actually SMEMBERS is just syntax sugar for SINTERSECT.
		-- Non existing keys are considered like empty sets,
		-- so if one of the keys is missing an empty set is returned (since the intersection with an empty set always is an empty set).
		require
			valid_argument: arguments /= Void and then not arguments.is_empty
			-- For each key in arguments if_exists_key_is_type_set : exists (a_key) implies (type (a_key) ~ type_set)
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make_from_array (arguments)
			send_command (sinter_command, l_arguments)
			Result := read_multi_bulk_reply
		end


	smove (a_src_key : STRING; a_dest_key : STRING; a_value : STRING) : INTEGER
		require
			valid_src : a_src_key /= Void
			valid_dest : a_dest_key /= Void
			valid_value : a_value /= Void
			if_exists_src_key_is_type_set : exists (a_src_key) implies (type (a_src_key) ~ type_set)
			if_exists_dest_key_is_type_set : exists (a_dest_key) implies (type (a_dest_key) ~ type_set)
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_src_key)
			l_arguments.force (a_dest_key)
			l_arguments.force (a_value)
			send_command (smove_command, l_arguments)
			Result := read_integer_reply
		end

	sinterstore (arguments : ARRAY[STRING])
		--Time complexity O(N*M) worst case where N is the cardinality of the smallest set and M the number of sets
		--This commnad works exactly like SINTER but instead of being returned the resulting set is sotred as dstkey.
		require
			valid_arguments : arguments /= Void and then arguments.count >= 2
			-- For each element in arguments if_exists_dest_key_is_type_set : exists (a_dest_key) implies (type (a_dest_key) ~ type_set)
		local
			l_arguments : ARRAYED_LIST[STRING]
			l_reply : STRING
		do
			create l_arguments.make_from_array (arguments)
			send_command (sinterstore_command, l_arguments)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

	sunion, set_union (arguments : ARRAY[STRING]) : LIST[STRING]
		--Time complexity O(N) where N is the total number of elements in all the provided sets
		--Return the members of a set resulting from the union of all the sets hold at the specified keys.
		--Like in LRANGE the result is sent to the client as a multi-bulk reply (see the protocol specification for more information).
		--If just a single key is specified, then this command produces the same result as SMEMBERS.
		--Non existing keys are considered like empty sets.
		require
			valid_arguments : arguments /= Void and then not arguments.is_empty
			-- For each element in arguments if_exists_dest_key_is_type_set : exists (a_dest_key) implies (type (a_dest_key) ~ type_set)
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make_from_array (arguments)
			send_command (sunion_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	sunionstore (arguments : ARRAY[STRING])
		--Time complexity O(N) where N is the total number of elements in all the provided sets
		--This command works exactly like SUNION but instead of being returned the resulting set is stored as dstkey.
		--Any existing value in dstkey will be over-written.
		require
			valid_arguments : arguments /= Void and then arguments.count >= 2
			-- For each element in arguments if_exists_dest_key_is_type_set : exists (a_dest_key) implies (type (a_dest_key) ~ type_set)
		local
			l_arguments : ARRAYED_LIST[STRING]
			l_reply : STRING
		do
			create l_arguments.make_from_array (arguments)
			send_command (sunionstore_command, l_arguments)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

	sdiff (arguments : ARRAY[STRING]) : LIST[STRING]
		--SDIFF 		key1 key2 ... keyN 				
		-- Return the difference between the Set stored at key1 and all the Sets key2, ..., keyN
		require
			valid_arguments : arguments /= Void and then not arguments.is_empty
			-- For each element in arguments if_exists_dest_key_is_type_set : exists (a_dest_key) implies (type (a_dest_key) ~ type_set)
		local
			l_arguments : ARRAYED_LIST[STRING]
			l_reply : STRING
		do
			create l_arguments.make_from_array (arguments)
			send_command (sdiff_command, l_arguments)
			Result := read_multi_bulk_reply
		end


	sdiffstore (arguments : ARRAY[STRING])
		require
			valid_arguments : arguments /= Void and then arguments.count >= 2
			-- For each element in arguments if_exists_dest_key_is_type_set : exists (a_dest_key) implies (type (a_dest_key) ~ type_set)
		local
			l_arguments : ARRAYED_LIST[STRING]
			l_reply : STRING
		do
			create l_arguments.make_from_array (arguments)
			send_command (sdiffstore_command, l_arguments)
			l_reply := read_status_reply
			check_reply (l_reply)
		end


	smembers (a_key : STRING) : LIST[STRING]
		require
			valid_key: a_key /= Void
			if_exists_key_is_type_set : exists (a_key) implies (type (a_key) ~ type_set)
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (smembers_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	srandmember (a_key : STRING) : STRING
		require
			valid_key: a_key /= Void
			if_exists_key_is_type_set : exists (a_key) implies (type (a_key) ~ type_set)
		local
			l_arguments : ARRAYED_LIST[STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (srandmember_command, l_arguments)
			Result := read_bulk_reply
		end

invariant
		non_empty_description: has_error implies (error_description /= Void and (not error_description.is_empty))
		socket_valid : socket /= Void
end
