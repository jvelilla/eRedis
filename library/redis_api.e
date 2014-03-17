note
	description: "{REDIS_API} for Redis 2.x protocol"
	author: "Javier Velilla"
	date: "$Date$"
	revision: "$Revision$"

class
	REDIS_API

inherit

	REDIS_CONSTANTS

create
	make, make_client_by_port

feature -- Initialization

	make_client_by_port (a_port: INTEGER; a_host: STRING)
			-- Create a redis client connection to port `a_port'
			-- and host `a_host'
		require
			valid_host: a_host /= Void
		do
			create socket.make_client_by_port (default_peer_port, a_host)
			socket.connect
			create last_reply.make_empty
		ensure
			is_connected: socket.is_connected
		end

	make
			-- Create an instance and make a connection to redis
			-- in the default port "localhost:6379"
		do
			create socket.make_client_by_port (default_peer_port, default_peer_host)
			socket.connect
			create last_reply.make_empty
		ensure
			is_connected: socket.is_connected
		end

feature {NONE} -- Implementation

	socket: NETWORK_STREAM_SOCKET
			-- connection to redis

	equal_redis_type (a_item: STRING; a_type: STRING): BOOLEAN
			-- Is the type of a_item equals to `a_tyep'?
		do
			Result := exists (a_item) implies (type (a_item) ~ a_type)
		end

	check_valid_response (a_response: STRING)
			-- Check if the response has an error,
			-- if there is an error, set has_error to true
			-- an set the error_description with the cause of the error
		do
			if is_valid_response (a_response) then
				clean_error
			else
				has_error := true
				full_message := a_response
			end
		end

	is_valid_response (a_response: STRING): BOOLEAN
			-- True if the response is valid, False in other case
		require
			not_null: a_response /= Void
		do
			Result := not (a_response.starts_with (error_response))
		end

	get_integer (a_key: STRING): INTEGER
		require
			if_exist_is_valid_key_and_value: exists (a_key) implies ((type (a_key) ~ type_string) and then attached get (a_key) as l_key and then l_key.is_integer_64)
		do
			if not exists (a_key) then
				Result := 0
			elseif attached get (a_key)as l_key then
				Result := l_key.to_integer
			end
		end

	response_range_withscore_internal: LIST [TUPLE [detachable STRING, detachable STRING]]
			-- Return a list of tuples (string,string)
		require
			is_connected: is_connected
		local
			l_list: LIST [detachable STRING]
			l_result: ARRAYED_LIST [TUPLE [detachable STRING, detachable STRING]]
			l_key: detachable STRING
			l_value: detachable STRING
		do
			l_list := read_multi_bulk_reply
			from
				l_list.start
				create l_result.make (l_list.count // 2)
			until
				l_list.after
			loop
				l_key := l_list.item_for_iteration
				l_list.forth
				check
					not l_list.after
				end
				l_value := l_list.item_for_iteration
				l_list.forth
				l_result.force ([l_key, l_value])
			end
			Result := l_result
		end

feature -- Redis Protocol

	read_status_reply: STRING
			-- Replies are single line
			-- "+.." SUCCESS
			-- "-.." ERROR
		require
			is_connected: is_connected
		do
			socket.read_line
			Result := socket.last_string
			check_valid_response (Result)
		end

	read_integer_reply: INTEGER
		require
			is_connected: is_connected
		local
			l_result: STRING
		do
			socket.read_line
			l_result := socket.last_string
			check_valid_response (l_result)
			if not has_error then
				Result := l_result.substring (2, l_result.count - 1).to_integer
			end
		end

	read_bulk_reply: detachable STRING
			--A bulk reply is a binary-safe reply that is used to return a binary safe single string value
			--(string is not limited to alphanumerical strings, it may contain binary data of any kind).
			--Client libraries will usually return a string as return value of Redis commands returning bulk replies.
			--There is a special bulk reply that signal that the element does not exist.
			--When this happens the client library should return 'nil', 'false',
			--or some other special element that can be distinguished by an empty string.
		local
			l_string: STRING
			l_bytes: INTEGER
		do
			socket.read_line
			l_string := socket.last_string
			check_valid_response (l_string)
			if not has_error then
				if not l_string.has_substring (null_response) then
					l_bytes := (l_string.substring (2, l_string.count - 1)).to_integer
					socket.read_stream_thread_aware (l_bytes)
					Result := socket.last_string
					socket.read_line
				end
			end
		end

	read_multi_bulk_reply: LIST [detachable STRING]
			--While a bulk reply returns a single string value,
			--multi bulk replies are used to return multiple values: lists, sets, and so on.
			--Elements of a bulk reply can be missing.
			--Client libraries should return 'nil' or 'false' in order to make this elements distinguishable from empty strings.
			--Client libraries should return multi bulk replies that are about ordered elements like list ranges as lists,
			-- and bulk replies about sets as hashes or Sets if the implementation language has a Set type.
		local
			l_string: STRING
			l_bytes: INTEGER
		do
				-- TODO clean this code
			create {ARRAYED_LIST[detachable STRING]}Result.make (10)
			socket.read_line
			l_string := socket.last_string
			check_valid_response (l_string)
			if not has_error then
				if l_string.has_substring (not_exist_key) then
					l_bytes := (l_string.substring (2, l_string.count - 1)).to_integer
					print ("The server return [" + l_bytes.out + "] responses")
				else
					from
					until
						not socket.is_readable
					loop
						socket.read_line
						l_string := socket.last_string
						if not l_string.has_substring (null_response) then
							l_bytes := (l_string.substring (2, l_string.count - 1)).to_integer
							socket.read_stream_thread_aware (l_bytes)
							Result.force (socket.last_string)
							socket.read_line
						else
								-- TODO check
							Result.force (Void)
						end
					end
				end
			end
		end

	full_message: detachable STRING
			-- Full error message

	check_reply (a_reply: STRING)
			--Check the single line reply
			-- If the reply contains as first character "+", is OK
			-- If the reply contains as first character "-", is ERROR
		do
			if a_reply.at (1).is_equal (minus_byte) then
				has_error := true
				full_message := "There was an error: {" + a_reply + "}"
			end
		end

	send_command (a_command: STRING; arguments: LIST [STRING])
		require
			is_valid_command: is_valid_redis_command (a_command)
			is_connnected: is_connected
			valid_arguments: arguments /= void
		do
			socket.put_string (asterisk_byte.out + (arguments.count + 1).out + crlf)
			socket.put_string (dollar_byte.out + a_command.count.out + crlf)
			socket.put_string (a_command + crlf)
			from
				arguments.start
			until
				arguments.after
			loop
				socket.put_string (dollar_byte.out + arguments.item_for_iteration.count.out + crlf)
				socket.put_string (arguments.item_for_iteration + crlf)
				arguments.forth
			end
		end

feature -- Close Connection

	close
			-- Close the connection
		require
			connected: is_connected
		do
			quit
			socket.close
			check
				socket.is_closed
			end
		ensure
			not_connected: socket.is_closed
		end

feature -- Status Report

	is_valid_aggregate_value (a_value: STRING): BOOLEAN
			-- Is `a_value' a valid aggregate_value (sum,min,max)?
		do
			aggregate_values.compare_objects
			Result := aggregate_values.has (a_value)
		end

	is_valid_key (a_key: STRING): BOOLEAN
			-- A key `a_key' is valid if it is not void
		do
			Result := a_key /= Void
		end

	is_valid_value (a_value: STRING): BOOLEAN
			-- A value `a_value' is valid if it is not void
		do
			Result := a_value /= Void
		end

	for_all_not_null (param: ARRAY [detachable STRING]): BOOLEAN
		require
			valid_param: param /= Void
		do
			Result := param.for_all (agent  (item: STRING): BOOLEAN
				do
					Result := item /= Void
				end)
		end

	for_all (a_collection: ARRAY [STRING]; a_type: STRING): BOOLEAN
			-- For all `item' in `a_collection', the type should be equal
			-- to `a_type', iff the item exist in the Database
		require
			not_void_collection: a_collection /= Void
			valid_redis_type: is_valid_redis_type (a_type)
		do
			Result := a_collection.for_all (agent equal_redis_type(?, a_type))
		end

	is_valid_redis_command (a_command: STRING): BOOLEAN
		require
			not_void: a_command /= Void
		do
			Result := redis_commands.has (a_command)
		end

	is_valid_redis_type (a_type: STRING): BOOLEAN
		require
			not_void: a_type /= Void
		do
			redis_types.compare_objects
			Result := redis_types.has (a_type)
		end

	has_error: BOOLEAN
			-- Did an error occur?

	is_connected: BOOLEAN
			-- Is the socket connection connected?
		do
			Result := socket.is_connected
		end

	error_description: detachable STRING
			-- Error description
		require
			has_error: has_error
		do
			Result := full_message
		end

	clean_error
			-- Remove the last error
		do
			has_error := False
			full_message := Void
		ensure
			not_has_error: not has_error
			not_message: full_message = Void
		end

feature -- Redis Connection Handling

	auth (a_password: STRING)
			--Request for authentication in a password protected Redis server.
			--A Redis server can be instructed to require a password before to allow clients to issue commands.
			--This is done using the requirepass directive in the Redis configuration file.
			--If the password given by the client is correct the server replies with an OK status code reply
			--and starts accepting commands from the client.
			--Otherwise an error is returned and the clients needs to try a new password.
			--Note that for the high performance nature of Redis it is possible to try a lot of passwords in parallel
			--in very short time, so make sure to generate a strong and very long password so that this attack is infeasible.
		require
			is_connected: is_connected
			valid_password: a_password /= Void
		local
			l_arguments: ARRAYED_LIST [STRING]
			l_reply: STRING
		do
			create l_arguments.make (1)
			l_arguments.force (a_password)
			send_command (auth_command, l_arguments)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

	quit
			-- Ask the server to silently close the connection.
		local
			l_arguments: ARRAYED_LIST [STRING]
			l_reply: STRING
		do
			create l_arguments.make (0)
			send_command (quit_command, l_arguments)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

	echo (a_message: STRING): detachable STRING
			--Echo the given string
		require
			is_connected: is_connected
			valid_message: a_message /= Void
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_message)
			send_command (echo_command, l_arguments)
			Result := read_bulk_reply
		ensure
			echo_response: Result ~ a_message
		end

	ping: STRING
			-- Ping the server
		require
			is_connected: is_connected
		local
			l_arguments: ARRAYED_LIST [STRING]
			l_result: STRING
		do
			create l_arguments.make (0)
			send_command (ping_command, l_arguments)
			l_result := read_status_reply
			Result := l_result.substring (2, l_result.count - 1)
		ensure
			ping_response: Result ~ "PONG"
		end

	select_db (an_index: INTEGER)
			-- Select the DB with having the specified zero-based numeric index.
			-- For default every new client connection is automatically selected to DB 0.
		require
			is_connected: is_connected
			valid_index: an_index >= 0
		local
			l_arguments: ARRAYED_LIST [STRING]
			reply: STRING
		do
			create l_arguments.make (1)
			l_arguments.force (an_index.out)
			send_command (select_command, l_arguments)
			reply := read_status_reply
			check_reply (reply)
		end

feature -- Redis Commands Keys

	exists (a_key: STRING): BOOLEAN
			-- Test if the specified key exists.
			-- The command returns `True' if the key exists, otherwise `False' is returned.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
		local
			l_arguments: ARRAYED_LIST [STRING]
			l_result: INTEGER
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (exists_command, l_arguments)
			l_result := read_integer_reply
			if l_result = 1 then
				Result := True
			end
		end

	persist (a_key: STRING)
			-- remove the expire from a key
			-- currently not supported
		require
			is_connected: is_connected
			valid_key: a_key /= Void
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (persist_command, l_arguments)
		end

	del (arguments: ARRAY [STRING]): INTEGER
			-- Remove the specified keys.
			-- If a given key does not exist no operation is performed for this key
			-- The command returns the number of keys removed.
		require
			is_connected: is_connected
			valid_arguments: arguments /= Void
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make_from_array (arguments)
			send_command (del_command, l_arguments)
			Result := read_integer_reply
		end

	type (a_key: STRING): STRING
			-- Return the type of the value stored at key in form of a string.
			-- The type can be one of "none", "string", "list", "set". "none" is returned if the key does not exist.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
		local
			l_arguments: ARRAYED_LIST [STRING]
			l_result: STRING
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (type_command, l_arguments)
			l_result := read_status_reply
			Result := l_result.substring (2, l_result.count - 1)
		ensure
			is_valid_type: is_valid_redis_type (Result)
		end

	rename_key (an_old_key: STRING; a_new_key: STRING)
			-- Atomically renames the key `an_old_key' to `a_new_key'.
			-- If the source and destination name are the same an error is returned.
			-- If newkey already exists it is overwritten.
		require
			is_connected: is_connected
			valid_keys: an_old_key /= Void and then a_new_key /= Void
			not_equals: not (an_old_key.same_string (a_new_key))
		local
			l_arguments: ARRAYED_LIST [STRING]
			reply: STRING
		do
			create l_arguments.make (2)
			l_arguments.force (an_old_key)
			l_arguments.force (a_new_key)
			send_command (rename_command, l_arguments)
			reply := read_status_reply
			check_reply (reply)
		end

	renamenx (an_old_key: STRING; a_new_key: STRING): INTEGER
			-- O(1) Renames key to newkey if newkey does not yet exist.
			-- It returns an error under the same conditions as RENAME.
		require
			is_connected: is_connected
			valid_keys: an_old_key /= Void and then a_new_key /= Void
			not_equals: not (an_old_key ~ a_new_key)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (an_old_key)
			l_arguments.force (a_new_key)
			send_command (renamenx_command, l_arguments)
			Result := read_integer_reply
		end

	keys (a_pattern: STRING): LIST [detachable STRING]
			-- Returns all the keys matching the glob-style pattern as space separated strings.
		require
			is_connected: is_connected
			valid_pattern: a_pattern /= Void
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_pattern)
			send_command (keys_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	randomkey: detachable STRING
			--Time complexity: O(1)
			--Return a randomly selected key from the currently selected DB.
		require
			is_connected: is_connected
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (0)
			send_command (randomkey_command, l_arguments)
			Result := read_bulk_reply
		end

	expire (a_key: STRING; a_seconds: INTEGER)
			-- set a time to live in seconds `a_seconds' on a key `a_key'
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_timeout: a_seconds > 0
		local
			l_arguments: ARRAYED_LIST [STRING]
			l_result: INTEGER
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_seconds.out)
			send_command (expire_command, l_arguments)
			l_result := read_integer_reply
		end

	ttl (a_key: STRING): INTEGER
			-- The TTL command returns the remaining time to live in seconds of a key that has an EXPIRE set.
			-- This introspection capability allows a Redis client to check how many seconds a given key will continue to be part of the dataset.
			-- If the Key does not exists or does not have an associated expire, -1 is returned.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (ttl_command, l_arguments)
			Result := read_integer_reply
		ensure
			valid_return: Result >= -1
		end

	move (a_key: STRING; an_index: INTEGER)
			-- Move the specified key from the currently selected DB to the specifieddestination DB.
			-- Note that this command returns 1 only if the key was successfully moved, and 0 if the target key was already there
			-- or if the source key was not found at all, so it is possible to use MOVE as a locking primitive.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_index: an_index >= 0
		local
			l_arguments: ARRAYED_LIST [STRING]
			l_result: INTEGER
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

feature -- Redis Commands Operating on Strings

	last_reply: STRING
			-- Last simple reply from Redis

	set (a_key: STRING; a_value: STRING)
			-- SET key value Set a key to a string value
			-- The string can't be longer than 1073741824 bytes
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_value: a_value /= Void and then a_value.count <= 1073741824
		local
			l_arguments: ARRAYED_LIST [STRING]
			reply: STRING
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_value)
			send_command (set_command, l_arguments)
			reply := read_status_reply
			check_reply (reply)
		end

	setnx (a_key: STRING; a_value: STRING): INTEGER
			--Time complexity: O(1)
			--SETNX works exactly like SET with the only difference that if the key already exists no operation is performed.
			--SETNX actually means "SET if Not eXists".
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_value: a_value /= Void and then a_value.count <= 1073741824
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_value)
			send_command (setnx_command, l_arguments)
			Result := read_integer_reply
		ensure
				-- Return 0 or 1
				-- if return 0 the key exist, if not the key does not exist but now it exist
		end

	setex (a_key: STRING; an_exp_time: INTEGER a_value: STRING)
			--Time complexity: O(1)
			--The command is exactly equivalent to the following group of commands:
			--  SET _key_ _value
			--	EXPIRE _key_ _time_
			--The operation is atomic. An atomic SET+EXPIRE operation was already provided using MULTI/EXEC,
			--but SETEX is a faster alternative provided because this operation is very common when Redis is used as a Cache.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_exp_time: an_exp_time > 0
			valid_value: a_value /= Void and then a_value.count <= 1073741824
		local
			l_arguments: ARRAYED_LIST [STRING]
			l_reply: STRING
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (an_exp_time.out)
			l_arguments.force (a_value)
			send_command (setex_command, l_arguments)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

	mset (a_params: HASH_TABLE [STRING, STRING])
			--Set the the respective keys to the respective values.
			--MSET will replace old values with new values
			--MSET is an atomic operation.
		require
			is_connected: is_connected
			valid_param: a_params /= Void
			-- each param should be a valid key and a valid value
		local
			l_arguments: ARRAYED_LIST [STRING]
			reply: STRING
		do
			create l_arguments.make (a_params.count * 2)
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

	msetnx (a_params: HASH_TABLE [STRING, STRING]): INTEGER
			--Time complexity: O(1) to set every key
			--MSETNX will not perform any operation at all even if just a single key already exists.
			--Because of this semantic MSETNX can be used in order to set
			--different keys representing different fields of an unique logic object in a way
			-- that ensures that either all the fields or none at all are set.
			-- Both MSET and MSETNX are atomic operations.
		require
			is_connected: is_connected
			valid_param: a_params /= Void
			-- each param should be a valid key and a valid value
		local
			l_arguments: ARRAYED_LIST [STRING]
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
			send_command (msetnx_command, l_arguments)
			Result := read_integer_reply
		end

	getset (a_key: STRING; a_value: STRING): detachable STRING
			--Time complexity: O(1)
			--GETSET is an atomic set this value and return the old value command.
			--Set key to the string value and return the old value stored at key.
			--The string can't be longer than 1073741824 bytes
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_value: a_value /= Void and then a_value.count <= 1073741824
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_value)
			send_command (getset_command, l_arguments)
			Result := read_bulk_reply
		end

	get (a_key: STRING): detachable STRING
			-- Get the value of the specified key.
			-- If the key does not exist the special value 'Void' is returned.
			-- If the value stored at key is not a string an error is returned because GET can only handle string values.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			if_the_key_exists_is_string: exists (a_key) implies (type (a_key) ~ type_string)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (get_command, l_arguments)
			Result := read_bulk_reply
		end

	mget (a_key: ARRAY [STRING]): LIST [detachable STRING]
			--Multi-get, return the strings values of the keys
		require
			is_connected: is_connected
			valid_keys: a_key /= Void and then not a_key.is_empty
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make_from_array (a_key)
			send_command (mget_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	incr (a_key: STRING): INTEGER
			--Time complexity: O(1)
			--Increment or decrement the number stored at key by one.
		require
			is_connected: is_connected
			valid_keys: a_key /= Void
			if_exist_is_valid_key_and_value: exists (a_key) implies ((type (a_key) ~ type_string) and then attached get (a_key) as l_key and then l_key.is_integer_64)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (incr_command, l_arguments)
			Result := read_integer_reply
		ensure
			increment: old (get_integer (a_key)) + 1 = get_integer (a_key)
		end

	incrby (a_key: STRING; a_value: INTEGER_64): INTEGER
			--Time complexity: O(1)
			--Increment the value of the `a_key' by `a_value'
		require
			is_connected: is_connected
			valid_keys: a_key /= Void
			if_exist_is_valid_key_and_value: exists (a_key) implies ((type (a_key) ~ type_string) and then attached get (a_key) as l_key and then l_key.is_integer_64)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_value.out)
			send_command (incrby_command, l_arguments)
			Result := read_integer_reply
		ensure
			increment: old (get_integer (a_key)) + a_value = get_integer (a_key)
		end

	decr (a_key: STRING): INTEGER
			--Time complexity: O(1)
			--Increment or decrement the number stored at key by one.
		require
			is_connected: is_connected
			valid_keys: a_key /= Void
			if_exist_is_valid_key_and_value: exists (a_key) implies ((type (a_key) ~ type_string) and then attached get (a_key) as l_key and then l_key.is_integer_64)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (decr_command, l_arguments)
			Result := read_integer_reply
		ensure
			increment: old (get_integer (a_key)) - 1 = get_integer (a_key)
		end

	decrby (a_key: STRING; a_value: INTEGER_64): INTEGER
			--Time complexity: O(1)
			--Decrement the value of the `a_key' by `a_value'
		require
			is_connected: is_connected
			valid_keys: a_key /= Void
			if_exist_is_valid_key_and_value: exists (a_key) implies ((type (a_key) ~ type_string) and then attached get (a_key) as l_key and then l_key.is_integer_64)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_value.out)
			send_command (decrby_command, l_arguments)
			Result := read_integer_reply
		ensure
			decrement: old (get_integer (a_key)) - a_value = get_integer (a_key)
		end

	append (a_key: STRING; a_value: STRING): INTEGER
			--Time complexity: O(1).
			--The amortized time complexity is O(1) assuming the appended value is small and the
			--already present value is of any size, since the dynamic string library used by Redis
			--will double the free space available on every reallocation.
			--If the key already exists and is a string,
			--this command appends the provided value at the end of the string.
			--If the key does not exist it is created and set as an empty string,
			--so APPEND will be very similar to SET in this special case.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_value: a_value /= Void
			if_exist_is_valid_key_and_value: exists (a_key) implies ((type (a_key) ~ type_string))
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_value)
			send_command (append_command, l_arguments)
			Result := read_integer_reply
		end

	substr (a_key: STRING; a_start: INTEGER; an_end: INTEGER): detachable STRING
			--Time complexity: O(start+n) (with start being the start index
			--and n the total length of the requested range).
			--Note that the lookup part of this command is O(1) so for
			--small strings this is actually an O(1) command.
			--Return a subset of the string from offset start
			--to offset end (both offsets are inclusive).
			--Negative offsets can be used in order to provide
			--an offset starting from the end of the string.
			--So -1 means the last char, -2 the penultimate and so forth.
			--The function handles out of range requests without raising an error,
			--but just limiting the resulting range to the actual length of the string.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			if_exist_is_valid_key_and_value: exists (a_key) implies ((type (a_key) ~ type_string))
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (a_start.out)
			l_arguments.force (an_end.out)
			send_command (substr_command, l_arguments)
			Result := read_bulk_reply
		end

feature -- Redis Commands Operating on Lists

	rpush (a_key: STRING; a_value: STRING): INTEGER
			-- Time complexity: O(1)
			-- Add the string value to the tail (RPUSH) of the liststored at key.
			-- If the key does not exist an empty list is created just beforethe append operation.
			-- If the key exists but is not a List an error is returned.
		require
			valid_key: a_key /= Void
			valid_value: a_value /= Void
			if_exists_key_is_type_list: exists (a_key) implies (type (a_key) ~ type_list)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_value)
			send_command (rpush_command, l_arguments)
			Result := read_integer_reply
		ensure
			valid_response: Result >= 0
			one_more_element: old (llen (a_key)) + 1 = llen (a_key)
		end

	lpush (a_key: STRING; a_value: STRING): INTEGER
			-- Time complexity: O(1)
			-- Add the string `a_value' to the head (LPUSH) of the list stored at `a_key'.
			-- If the `a_key' does not exist an empty list is created just before the append operation.
			-- If the `a_key' exists but is not a List an error is returned.
		require
			valid_key: a_key /= Void
			valid_value: a_value /= Void
			if_exists_key_is_type_list: exists (a_key) implies (type (a_key) ~ type_list)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_value)
			send_command (lpush_command, l_arguments)
			Result := read_integer_reply
		ensure
			valid_response: Result >= 0
			one_more_element: old (llen (a_key)) + 1 = llen (a_key)
		end

	llen (a_key: STRING): INTEGER
			-- Time complexity: O(1)
			-- Return the length of the list stored at the specified `a_key'.
			-- If the `a_key' does not exist zero is returned (the same behaviour as for empty lists).
			-- If the value stored at `a_key' is not a list an error is returned.
		require
			valid_key: a_key /= Void
			if_exists_key_is_type_list: exists (a_key) implies (type (a_key) ~ type_list)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (llen_command, l_arguments)
			Result := read_integer_reply
		ensure
			valid_result: Result >= 0
		end

	lrange (a_key: STRING; an_start: INTEGER; an_end: INTEGER): LIST [detachable STRING]
			--Time complexity: O(start+n) (with n being the length of the range and start being the start offset)
			--Return the specified elements of the list stored at the specified key. Start and end are zero-based indexes.
			--0 is the first element of the list (the list head), 1 the next element and so on.
			--For example LRANGE foobar 0 2 will return the first three elements of the list.
			--start and end can also be negative numbers indicating offsets from the end of the list.
			--For example -1 is the last element of the list, -2 the penultimate element and so on.
		require
			valid_key: a_key /= Void
			if_exists_key_is_type_list: exists (a_key) implies (type (a_key) ~ type_list)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (an_start.out)
			l_arguments.force (an_end.out)
			send_command (lrange_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	ltrim (a_key: STRING; an_start: INTEGER; an_end: INTEGER)
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
			valid_key: a_key /= Void
			if_exists_key_is_type_list: exists (a_key) implies (type (a_key) ~ type_list)
		local
			l_arguments: ARRAYED_LIST [STRING]
			l_reply: STRING
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (an_start.out)
			l_arguments.force (an_end.out)
			send_command (ltrim_command, l_arguments)
			l_reply := read_status_reply
			check_reply (l_reply)
		ensure
			valid_status: not has_error
		end

	lindex (a_key: STRING; an_index: INTEGER): detachable STRING
			--Time complexity: O(n) (with n being the length of the list)
			--Return the specified element of the list stored at the specified key.
			--0 is the first element, 1 the second and so on.
			--Negative indexes are supported, for example -1 is the last element, -2 the penultimate and so on.
			--If the value stored at key is not of list type an error is returned.
			--If the index is out of range a 'nil' reply is returned.
			--Note that even if the average time complexity is O(n) asking for the first or the last element of the list is O(1).
		require
			valid_key: a_key /= Void
			if_exists_key_is_type_list: exists (a_key) implies (type (a_key) ~ type_list)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (an_index.out)
			send_command (lindex_command, l_arguments)
			Result := read_bulk_reply
		end

	lset (a_key: STRING; an_index: INTEGER; a_value: STRING)
			-- Time complexity: O(N) (with N being the length of the list)
			-- Set the list element at index (see LINDEX for information about the index argument) with the new value.
			-- Out of range indexes will generate an error. Note that setting the first or last elements of the list is O(1).
			-- Similarly to other list commands accepting indexes, the index can be negative to access elements starting from the end of the list.
			-- So -1 is the last element, -2 is the penultimate, and so forth.
		require
			valid_key: a_key /= Void
			valid_value: a_value /= Void
			if_exists_key_is_type_list: exists (a_key) implies (type (a_key) ~ type_list)
		local
			l_arguments: ARRAYED_LIST [STRING]
			l_reply: STRING
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (an_index.out)
			l_arguments.force (a_value)
			send_command (lset_command, l_arguments)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

	lrem (a_key: STRING; a_count: INTEGER; a_value: STRING): INTEGER
		require
			valid_key: a_key /= Void
			valid_value: a_value /= Void
			if_exists_key_is_type_list: exists (a_key) implies (type (a_key) ~ type_list)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (a_count.out)
			l_arguments.force (a_value)
			send_command (lrem_command, l_arguments)
			Result := read_integer_reply
		ensure
			valid_response: Result >= 0
		end

	lpop (a_key: STRING): detachable STRING
			--Time complexity: O(1)
			--Atomically return and remove the first (LPOP)  element of the list.
			--For example if the list contains the elements "a","b","c" LPOP will return "a" and the list will become "b","c".
			--If the key does not exist or the list is already empty the special value 'nil' is returned.
		require
			valid_key: a_key /= Void
			if_exists_key_is_type_list: exists (a_key) implies (type (a_key) ~ type_list)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (lpop_command, l_arguments)
			Result := read_bulk_reply
		end

	rpop (a_key: STRING): detachable STRING
			--Time complexity: O(1)
			--Atomically return and remove the last (RPOP)  element of the list.
			--For example if the list contains the elements "a","b","c" RPOP will return "c" and the list will become "a","b".
			--If the key does not exist or the list is already empty the special value 'nil' is returned.
		require
			valid_key: a_key /= Void
			if_exists_key_is_type_list: exists (a_key) implies (type (a_key) ~ type_list)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (rpop_command, l_arguments)
			Result := read_bulk_reply
		end

	blpop (arguments: ARRAY [STRING]; a_timeout: INTEGER): LIST [detachable STRING]
			--Time complexity: O(1)
			--BLPOP (and BRPOP) is a blocking list pop primitive.
			--You can see this commands as blocking versions of LPOP and RPOP able to block if the specified
			--keys don't exist or contain empty lists.
			--The following is a description of the exact semantic.
			--We describe BLPOP but the two commands are identical, the only difference is that BLPOP pops the
			--element from the left (head) of the list, and BRPOP pops from the right (tail).
		require
			valid_arguments: arguments /= void
			for_all_exists_key_is_type_list: for_all (arguments, type_list)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make_from_array (arguments)
			l_arguments.force (a_timeout.out)
			send_command (blpop_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	brpop (arguments: ARRAY [STRING]; a_timeout: INTEGER): LIST [detachable STRING]
			--Time complexity: O(1)
			--BLPOP (and BRPOP) is a blocking list pop primitive.
			--You can see this commands as blocking versions of LPOP and RPOP able to block if the specified
			--keys don't exist or contain empty lists.
			--The following is a description of the exact semantic.
			--We describe BLPOP but the two commands are identical, the only difference is that BLPOP pops the
			--element from the left (head) of the list, and BRPOP pops from the right (tail).
		require
			valid_arguments: arguments /= void
			for_all_exists_key_is_type_list: for_all (arguments, type_list)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make_from_array (arguments)
			l_arguments.force (a_timeout.out)
			send_command (brpop_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	rpoplpush (a_src_key: STRING; a_dest_key: STRING): detachable STRING
		require
			valid_src_key: a_src_key /= Void
			valid_dest_key: a_dest_key /= Void
			if_exists_src_key_is_type_list: exists (a_src_key) implies (type (a_src_key) ~ type_list)
			if_exists_dest_key_is_type_list: exists (a_dest_key) implies (type (a_dest_key) ~ type_list)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_src_key)
			l_arguments.force (a_dest_key)
			send_command (rpoplpush_command, l_arguments)
			Result := read_bulk_reply
		end

feature -- Redis Commands Operating on Sets

	sadd, set_add (a_key: STRING; a_member: STRING): INTEGER
			--Time complexity O(1)
			-- Add the specified member to the set value stored at key.
			-- If member is already a member of the set no operation is performed.
			-- If key does not exist a new set with the specified member as sole member is created.
			-- If the key exists but does not hold a set value an error is returned.
		require
			valid_key: a_key /= Void
			valid_membe: a_member /= Void
			if_exists_key_is_type_set: exists (a_key) implies (type (a_key) ~ type_set)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_member)
			send_command (sadd_command, l_arguments)
			Result := read_integer_reply
		ensure
			valid_response: Result >= 0
		end

	srem, set_remove (a_key: STRING; a_member: STRING): INTEGER
			-- Time complexity O(1)
			-- Remove the specified member from the set value stored at key.
			-- If member was not a member of the set no operation is performed.
			-- If key does not hold a set value an error is returned.
		require
			valid_key: a_key /= Void
			valid_membe: a_member /= Void
			if_exists_key_is_type_set: exists (a_key) implies (type (a_key) ~ type_set)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_member)
			send_command (srem_command, l_arguments)
			Result := read_integer_reply
		ensure
			valid_response: Result >= 0
		end

	spop, set_pop (a_key: STRING): detachable STRING
			--	Time complexity O(1)
			--  Remove a random element from a Set returning it as return value.
			--  If the Set is empty or the key does not exist, a nil object is returned.
			-- 	The SRANDMEMBER command does a similar work but the returned element is not removed from the Set.
		require
			valid_key: a_key /= Void
			if_exists_key_is_type_set: exists (a_key) implies (type (a_key) ~ type_set)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (spop_command, l_arguments)
			Result := read_bulk_reply
		end

	scard, set_cardinality (a_key: STRING): INTEGER
			-- Time complexity O(1)
			-- Return the set cardinality (number of elements).
			-- If the key does not exist 0 is returned, like for empty sets.
		require
			valid_key: a_key /= Void
			if_exists_key_is_type_set: exists (a_key) implies (type (a_key) ~ type_set)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (scard_command, l_arguments)
			Result := read_integer_reply
		ensure
			valid_response: Result >= 0
		end

	sismember, set_is_member (a_key: STRING; a_value: STRING): BOOLEAN
		require
			valid_key: a_key /= Void
			valid_value: a_value /= Void
			if_exists_key_is_type_set: exists (a_key) implies (type (a_key) ~ type_set)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_value)
			send_command (sismember_command, l_arguments)
			Result := (read_integer_reply = 1)
		end

	sinter (arguments: ARRAY [STRING]): LIST [detachable STRING]
			--Time complexity O(N*M) worst case where N is the cardinality of the smallest set and M the number of sets
			--Return the members of a set resulting from the intersection of all the sets hold at the specified keys.
			-- Like in LRANGE the result is sent to the client as a multi-bulk reply (see the protocol specification for more information).
			-- If just a single key is specified, then this command produces the same result as SMEMBERS.
			-- Actually SMEMBERS is just syntax sugar for SINTERSECT.
			-- Non existing keys are considered like empty sets,
			-- so if one of the keys is missing an empty set is returned (since the intersection with an empty set always is an empty set).
		require
			valid_argument: arguments /= Void and then not arguments.is_empty
			valid_type_for_each_element: for_all (arguments, type_set)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make_from_array (arguments)
			send_command (sinter_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	smove (a_src_key: STRING; a_dest_key: STRING; a_value: STRING): INTEGER
		require
			valid_src: a_src_key /= Void
			valid_dest: a_dest_key /= Void
			valid_value: a_value /= Void
			if_exists_src_key_is_type_set: exists (a_src_key) implies (type (a_src_key) ~ type_set)
			if_exists_dest_key_is_type_set: exists (a_dest_key) implies (type (a_dest_key) ~ type_set)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_src_key)
			l_arguments.force (a_dest_key)
			l_arguments.force (a_value)
			send_command (smove_command, l_arguments)
			Result := read_integer_reply
		end

	sinterstore (arguments: ARRAY [STRING])
			--Time complexity O(N*M) worst case where N is the cardinality of the smallest set and M the number of sets
			--This commnad works exactly like SINTER but instead of being returned the resulting set is sotred as dstkey.
		require
			valid_arguments: arguments /= Void and then arguments.count >= 2
			valid_type_for_each_element: for_all (arguments, type_set)
		local
			l_arguments: ARRAYED_LIST [STRING]
			l_reply: STRING
		do
			create l_arguments.make_from_array (arguments)
			send_command (sinterstore_command, l_arguments)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

	sunion, set_union (arguments: ARRAY [STRING]): LIST [detachable STRING]
			--Time complexity O(N) where N is the total number of elements in all the provided sets
			--Return the members of a set resulting from the union of all the sets hold at the specified keys.
			--Like in LRANGE the result is sent to the client as a multi-bulk reply (see the protocol specification for more information).
			--If just a single key is specified, then this command produces the same result as SMEMBERS.
			--Non existing keys are considered like empty sets.
		require
			valid_arguments: arguments /= Void and then not arguments.is_empty
			valid_type_for_each_element: for_all (arguments, type_set)
			valid_element: for_all_not_null (arguments)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make_from_array (arguments)
			send_command (sunion_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	sunionstore (arguments: ARRAY [STRING])
			--Time complexity O(N) where N is the total number of elements in all the provided sets
			--This command works exactly like SUNION but instead of being returned the resulting set is stored as dstkey.
			--Any existing value in dstkey will be over-written.
		require
			valid_arguments: arguments /= Void and then arguments.count >= 2
			valid_type_for_each_element: for_all (arguments, type_set)
		local
			l_arguments: ARRAYED_LIST [STRING]
			l_reply: STRING
		do
			create l_arguments.make_from_array (arguments)
			send_command (sunionstore_command, l_arguments)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

	sdiff (arguments: ARRAY [STRING]): LIST [detachable STRING]
			--Time complexity O(N) with N being the total number of elements of all the sets
			-- Return the members of a set resulting from the difference between the first set provided and all the successive sets.
		require
			valid_arguments: arguments /= Void and then not arguments.is_empty
			valid_type_for_each_element: for_all (arguments, type_set)
			valid_elements: for_all_not_null (arguments)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make_from_array (arguments)
			send_command (sdiff_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	sdiffstore (arguments: ARRAY [STRING])
			--Time complexity O(N) where N is the total number of elements in all the provided sets
			--This command works exactly like SDIFF but instead of being returned the resulting set is stored in dstkey.
		require
			valid_arguments: arguments /= Void and then arguments.count >= 2
			valid_type_for_each_element: for_all (arguments, type_set)
		local
			l_arguments: ARRAYED_LIST [STRING]
			l_reply: STRING
		do
			create l_arguments.make_from_array (arguments)
			send_command (sdiffstore_command, l_arguments)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

	smembers (a_key: STRING): LIST [detachable STRING]
			--Time complexity O(N)
			--Return all the members (elements) of the set value stored at key.
			--This is just syntax glue for SINTER.
		require
			valid_key: a_key /= Void
			if_exists_key_is_type_set: exists (a_key) implies (type (a_key) ~ type_set)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (smembers_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	srandmember (a_key: STRING): detachable STRING
			--Time complexity O(1)
			--Return a random element from a Set, without removing the element.
			--If the Set is empty or the key does not exist, a nil object is returned.
			--The SPOP command does a similar work but the returned element is popped (removed) from the Set.
		require
			valid_key: a_key /= Void
			if_exists_key_is_type_set: exists (a_key) implies (type (a_key) ~ type_set)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (srandmember_command, l_arguments)
			Result := read_bulk_reply
		end

feature -- Redis Commands Operating on ZSets (sorted sets)

	zadd (a_key: STRING; a_score: DOUBLE; a_value: STRING): INTEGER
			--Time complexity O(log(N)) with N being the number of elements in the sorted set
			--Add the specified member having the specifeid score to the sorted set stored at key.
			--If member is already a member of the sorted set the score is updated,
			--and the element reinserted in the right position to ensure sorting.
			--If key does not exist a new sorted set with the specified member as sole member is crated.
			--If the key exists but does not hold a sorted set value an error is returned.
			--The score value can be the string representation of a double precision floating point number.
		require
			is_connected: is_connected
			a_valid_key: a_key /= Void
			a_valid_value: a_value /= Void
			if_key_exist_is_type_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (a_score.out)
			l_arguments.force (a_value)
			send_command (zadd_command, l_arguments)
			Result := read_integer_reply
		ensure
			Response_0_or_1: Result = 1 or else Result = 0
		end

	zrem (a_key: STRING; a_value: STRING): INTEGER
			--Time complexity O(log(N)) with N being the number of elements in the sorted set
			--Remove the specified member from the sorted set value stored at key.
			--If member was not a member of the set no operation is performed.
			--If key does not not hold a set value an error is returned.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_value: a_value /= Void
			if_key_exists_is_type_zet: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_value)
			send_command (zrem_command, l_arguments)
			Result := read_integer_reply
		ensure
			Result_0_or_1: Result = 1 or else Result = 0
		end

	zincrby (a_key: STRING; an_increment: DOUBLE; a_value: STRING): detachable STRING
			--Time complexity O(log(N)) with N being the number of elements in the sorted set
			--If member already exists in the sorted set adds the increment to its score and
			--updates the position of the element in the sorted set accordingly.
			--If member does not already exist in the sorted set it is added with increment as score
			--(that is, like if the previous score was virtually zero).
			--If key does not exist a new sorted set with the specified member as sole member is crated.
			--If the key exists but does not hold a sorted set value an error is returned.
			--The score value can be the string representation of a double precision floating point number.
			--It's possible to provide a negative value to perform a decrement.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_value: a_value /= Void
			if_key_exists_if_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (an_increment.out)
			l_arguments.force (a_value)
			send_command (zincrby_command, l_arguments)
			Result := read_bulk_reply
		end

	zrank (a_key: STRING; a_member: STRING): INTEGER
			--Time complexity: O(log(N))
			--ZRANK returns the rank of the member in the sorted set, with scores ordered from low to high.
			--When the given member does not exist in the sorted set, the special value '-1' is returned.
			--The returned rank (or index) of the member is 0-based
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_member: a_member /= Void
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_member)
			send_command (zrank_command, l_arguments)
			Result := read_integer_reply
		ensure
			Response: Result >= -1
		end

	zrevrank (a_key: STRING; a_member: STRING): INTEGER
			--Time complexity: O(log(N))
			--ZREVRANK returns the rank of the member in the sorted set, with scores ordered from high to low.
			--When the given member does not exist in the sorted set, the special value '-1' is returned.
			--The returned rank (or index) of the member is 0-based
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_member: a_member /= Void
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_member)
			send_command (zrevrank_command, l_arguments)
			Result := read_integer_reply
		ensure
			Response: Result >= -1
		end

	zrange (a_key: STRING; a_start: INTEGER; an_end: INTEGER): LIST [detachable STRING]
			--Time complexity: O(log(N))+O(M) (with N being the number of elements in the sorted set and M the number of elements requested)
			--Return the specified elements of the sorted set at the specified key.
			--The elements are considered sorted from the lowerest to the highest score when using ZRANGE,
			--and in the reverse order when using ZREVRANGE. Start and end are zero-based indexes.
			--0 is the first element of the sorted set (the one with the lowerest score when using ZRANGE),
			--1 the next element by score and so on.
			--start and end can also be negative numbers indicating offsets from the end of the sorted set.
			--For example -1 is the last element of the sorted set, -2 the penultimate element and so on.
			--Indexes out of range will not produce an error:
			--if start is over the end of the sorted set, or start > end, an empty list is returned.
			--If end is over the end of the sorted set Redis will threat it just like the last element of the sorted set.
			--It's possible to pass the WITHSCORES option to the command in order to return not only the values but also
			--the scores of the elements.
			--Redis will return the data as a single list composed of value1,score1,value2,score2,...,valueN,scoreN
			--but client libraries are free to return a more appropriate data type
			--(what we think is that the best return type for this command is a Array of two-elements Array /
			-- Tuple in order to preserve sorting).
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (a_start.out)
			l_arguments.force (an_end.out)
			send_command (zrange_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	zrange_withscores (a_key: STRING; a_start: INTEGER; an_end: INTEGER): LIST [TUPLE [detachable STRING, detachable STRING]]
			--Time complexity: O(log(N))+O(M) (with N being the number of elements in the sorted set and M the number of elements requested)
			--Return the specified elements of the sorted set at the specified key.
			--The elements are considered sorted from the lowerest to the highest score when using ZRANGE,
			--and in the reverse order when using ZREVRANGE. Start and end are zero-based indexes.
			--0 is the first element of the sorted set (the one with the lowerest score when using ZRANGE),
			--1 the next element by score and so on.
			--start and end can also be negative numbers indicating offsets from the end of the sorted set.
			--For example -1 is the last element of the sorted set, -2 the penultimate element and so on.
			--Indexes out of range will not produce an error:
			--if start is over the end of the sorted set, or start > end, an empty list is returned.
			--If end is over the end of the sorted set Redis will threat it just like the last element of the sorted set.
			--It's possible to pass the WITHSCORES option to the command in order to return not only the values but also
			--the scores of the elements.
			--Redis will return the data as a single list composed of value1,score1,value2,score2,...,valueN,scoreN
			--but client libraries are free to return a more appropriate data type
			--(what we think is that the best return type for this command is a Array of two-elements Array /
			-- Tuple in order to preserve sorting).
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (4)
			l_arguments.force (a_key)
			l_arguments.force (a_start.out)
			l_arguments.force (an_end.out)
			l_arguments.force (withscores)
			send_command (zrange_command, l_arguments)
			Result := response_range_withscore_internal
		end

	zrevrange (a_key: STRING; a_start: INTEGER; an_end: INTEGER): LIST [detachable STRING]
			--Time complexity: O(log(N))+O(M) (with N being the number of elements in the sorted set and M the number of elements requested)
			--Return the specified elements of the sorted set at the specified key.
			--The elements are considered sorted from the lowerest to the highest score when using ZRANGE,
			--and in the reverse order when using ZREVRANGE. Start and end are zero-based indexes.
			--0 is the first element of the sorted set (the one with the lowerest score when using ZRANGE),
			--1 the next element by score and so on.
			--start and end can also be negative numbers indicating offsets from the end of the sorted set.
			--For example -1 is the last element of the sorted set, -2 the penultimate element and so on.
			--Indexes out of range will not produce an error:
			--if start is over the end of the sorted set, or start > end, an empty list is returned.
			--If end is over the end of the sorted set Redis will threat it just like the last element of the sorted set.
			--It's possible to pass the WITHSCORES option to the command in order to return not only the values but also
			--the scores of the elements.
			--Redis will return the data as a single list composed of value1,score1,value2,score2,...,valueN,scoreN
			--but client libraries are free to return a more appropriate data type
			--(what we think is that the best return type for this command is a Array of two-elements Array /
			-- Tuple in order to preserve sorting).
			--
			--
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (a_start.out)
			l_arguments.force (an_end.out)
			send_command (zrevrange_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	zrevrange_withscores (a_key: STRING; a_start: INTEGER; an_end: INTEGER): LIST [TUPLE [detachable STRING, detachable STRING]]
			--Time complexity: O(log(N))+O(M) (with N being the number of elements in the sorted set and M the number of elements requested)
			--Return the specified elements of the sorted set at the specified key.
			--The elements are considered sorted from the lowerest to the highest score when using ZRANGE,
			--and in the reverse order when using ZREVRANGE. Start and end are zero-based indexes.
			--0 is the first element of the sorted set (the one with the lowerest score when using ZRANGE),
			--1 the next element by score and so on.
			--start and end can also be negative numbers indicating offsets from the end of the sorted set.
			--For example -1 is the last element of the sorted set, -2 the penultimate element and so on.
			--Indexes out of range will not produce an error:
			--if start is over the end of the sorted set, or start > end, an empty list is returned.
			--If end is over the end of the sorted set Redis will threat it just like the last element of the sorted set.
			--It's possible to pass the WITHSCORES option to the command in order to return not only the values but also
			--the scores of the elements.
			--Redis will return the data as a single list composed of value1,score1,value2,score2,...,valueN,scoreN
			--but client libraries are free to return a more appropriate data type
			--(what we think is that the best return type for this command is a Array of two-elements Array /
			-- Tuple in order to preserve sorting).
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (4)
			l_arguments.force (a_key)
			l_arguments.force (a_start.out)
			l_arguments.force (an_end.out)
			l_arguments.force (withscores)
			send_command (zrevrange_command, l_arguments)
			Result := response_range_withscore_internal
		end

	zrangebyscore (a_key: STRING; a_min: DOUBLE; a_max: DOUBLE): LIST [detachable STRING]
			--Time complexity: O(log(N))+O(M) with N being the number of elements in the sorted set and M
			--the number of elements returned by the command, so if M is constant
			--(for instance you always ask for the first ten elements with LIMIT) you can consider it O(log(N))
			--Return the all the elements in the sorted set at key with a score between min and max
			--(including elements with score equal to min or max).
			--The elements having the same score are returned sorted lexicographically as ASCII strings
			--(this follows from a property of Redis sorted sets and does not involve further computation).
			--Using the optional LIMIT it's possible to get only a range of the matching elements in an SQL-alike way.
			--Note that if offset is large the commands needs to traverse the list for offset elements and this adds up to the O(M) figure.
			--The ZCOUNT command is similar to ZRANGEBYSCORE but instead of returning the actual elements in the specified interval,
			--it just returns the number of matching elements.
			--Exclusive intervals and infinity
			--min and max can be -inf and +inf, so that you are not required to know what's the greatest or smallest element in order
			--to take, for instance, elements "up to a given value".
			--Also while the interval is for default closed (inclusive) it's possible to specify open intervals prefixing the score with a "(" character, so for instance:
			--
			--TODO implement ZRANGEBYSCORE key min max [LIMIT offset count] [WITHSCORES]
			--
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (a_min.out)
			l_arguments.force (a_max.out)
			send_command (zrangebyscore_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	zrangebyscore_withscores (a_key: STRING; a_min: DOUBLE; a_max: DOUBLE): LIST [TUPLE [detachable STRING, detachable STRING]]
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (4)
			l_arguments.force (a_key)
			l_arguments.force (a_min.out)
			l_arguments.force (a_max.out)
			l_arguments.force (withscores)
			send_command (zrangebyscore_command, l_arguments)
			Result := response_range_withscore_internal
		end

	zrangebyscore_limit (a_key: STRING; a_min: DOUBLE; a_max: DOUBLE; offset: INTEGER; count: INTEGER): LIST [detachable STRING]
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (6)
			l_arguments.force (a_key)
			l_arguments.force (a_min.out)
			l_arguments.force (a_max.out)
			l_arguments.force (limit)
			l_arguments.force (offset.out)
			l_arguments.force (count.out)
			send_command (zrangebyscore_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	zrangebyscore_limit_withscores (a_key: STRING; a_min: DOUBLE; a_max: DOUBLE; offset: INTEGER; count: INTEGER): LIST [TUPLE [detachable STRING, detachable STRING]]
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (7)
			l_arguments.force (a_key)
			l_arguments.force (a_min.out)
			l_arguments.force (a_max.out)
			l_arguments.force (limit)
			l_arguments.force (offset.out)
			l_arguments.force (count.out)
			l_arguments.force (withscores)
			send_command (zrangebyscore_command, l_arguments)
			Result := response_range_withscore_internal
		end

	zcount (a_key: STRING; a_min: DOUBLE; a_max: DOUBLE): INTEGER
			--Time complexity: O(log(N))+O(M) with N being the number of elements in the sorted set and M
			--the number of elements returned by the command, so if M is constant
			--(for instance you always ask for the first ten elements with LIMIT) you can consider it O(log(N))
			--Return the all the elements in the sorted set at key with a score between min and max
			--(including elements with score equal to min or max).
			--The elements having the same score are returned sorted lexicographically as ASCII strings
			--(this follows from a property of Redis sorted sets and does not involve further computation).
			--Using the optional LIMIT it's possible to get only a range of the matching elements in an SQL-alike way.
			--Note that if offset is large the commands needs to traverse the list for offset elements and this adds up to the O(M) figure.
			--The ZCOUNT command is similar to ZRANGEBYSCORE but instead of returning the actual elements in the specified interval,
			--it just returns the number of matching elements.
			--Exclusive intervals and infinity
			--min and max can be -inf and +inf, so that you are not required to know what's the greatest or smallest element in order
			--to take, for instance, elements "up to a given value".
			--Also while the interval is for default closed (inclusive) it's possible to specify open intervals prefixing the score with a "(" character, so for instance:
			--
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (a_min.out)
			l_arguments.force (a_max.out)
			send_command (zcount_command, l_arguments)
			Result := read_integer_reply
		end

	zcard (a_key: STRING): INTEGER
			--Time complexity O(1)
			--Return the sorted set cardinality (number of elements).
			--If the key does not exist 0 is returned, like for empty sorted sets.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (zcard_command, l_arguments)
			Result := read_integer_reply
		ensure
			Response: Result >= 0
		end

	zscore (a_key: STRING; an_element: STRING): detachable STRING
			--Time complexity O(1)
			--Return the score of the specified element of the sorted set at key.
			--If the specified element does not exist in the sorted set, or the key does not exist at all,
			--a special 'Void' value is returned.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_element: an_element /= Void
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (an_element)
			send_command (zscore_command, l_arguments)
			Result := read_bulk_reply
		end

	zremrangebyrank (a_key: STRING; a_min: INTEGER; a_max: INTEGER): INTEGER
			--Time complexity: O(log(N))+O(M) with N being the number of elements in the sorted set
			--and M the number of elements removed by the operation
			--Remove all elements in the sorted set at key with rank between start and end.
			-- Start and end are 0-based with rank 0 being the element with the lowest score.
			--Both start and end can be negative numbers, where they indicate offsets starting at the element with the highest rank.
			--For example: -1 is the element with the highest score, -2 the element with the second highest score and so forth.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (a_min.out)
			l_arguments.force (a_max.out)
			send_command (zremrangebyrank_command, l_arguments)
			Result := read_integer_reply
		end

	zremrangebyscore (a_key: STRING; a_min: DOUBLE; a_max: DOUBLE): INTEGER
			--Time complexity: O(log(N))+O(M) with N being the number of elements in the sorted set and
			--M the number of elements removed by the operation
			--Remove all the elements in the sorted set at key with a score between min and max
			--(including elements with score equal to min or max).
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (a_min.out)
			l_arguments.force (a_max.out)
			send_command (zremrangebyscore_command, l_arguments)
			Result := read_integer_reply
		end

	zunionstore (a_key: STRING; arguments: ARRAY [STRING]): INTEGER
			--Time complexity: O(N) + O(M log(M)) with N being the sum of the sizes of the input sorted sets,
			--and M being the number of elements in the resulting sorted set
			--Creates a union or intersection of N sorted sets given by keys k1 through kN, and stores it at dstkey.
			--It is mandatory to provide the number of input keys N, before passing the input keys and the other (optional) arguments.
			--As the terms imply, the ZINTERSTORE command requires an element to be present in each of the given inputs
			--to be inserted in the result. The ZUNIONSTORE command inserts all elements across all inputs.
			--Using the WEIGHTS option, it is possible to add weight to each input sorted set.
			--This means that the score of each element in the sorted set is first multiplied by this weight
			--before being passed to the aggregation. When this option is not given, all weights default to 1.
			--With the AGGREGATE option, it's possible to specify how the results of the union or intersection are aggregated.
			--This option defaults to SUM, where the score of an element is summed across the inputs where it exists.
			--When this option is set to be either MIN or MAX, the resulting set will contain the minimum or maximum score of an
			--element across the inputs where it exists.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_argument: arguments /= Void and then not arguments.is_empty
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make_from_array (arguments)
			l_arguments.put_front (arguments.count.out)
			l_arguments.put_front (a_key)
			send_command (zunionstore_command, l_arguments)
			Result := read_integer_reply
		end

	zunionstore_weights (a_key: STRING; arguments: ARRAY [STRING]; a_weights: ARRAY [STRING]): INTEGER
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_argument: arguments /= Void and then not arguments.is_empty
			valid_weights: a_weights /= Void and then not a_weights.is_empty
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
			i: INTEGER
		do
			create l_arguments.make_from_array (arguments)
			l_arguments.put_front (arguments.count.out)
			l_arguments.put_front (a_key)
			l_arguments.force (weights)
			from
				i := 1
			until
				i > a_weights.count
			loop
				l_arguments.force (a_weights.at (i))
				i := i + 1
			end
			send_command (zunionstore_command, l_arguments)
			Result := read_integer_reply
		end

	zunionstore_aggregate (a_key: STRING; arguments: ARRAY [STRING]; an_aggregate: STRING): INTEGER
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_argument: arguments /= Void and then not arguments.is_empty
			is_valid_aggregate: an_aggregate /= Void and then is_valid_aggregate_value (an_aggregate)
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make_from_array (arguments)
			l_arguments.put_front (arguments.count.out)
			l_arguments.put_front (a_key)
			l_arguments.force (aggregate)
			l_arguments.force (an_aggregate)
			send_command (zunionstore_command, l_arguments)
			Result := read_integer_reply
		end

	zunionstore_weights_aggregate (a_key: STRING; arguments: ARRAY [STRING]; a_weights: ARRAY [STRING]; an_aggregate: STRING): INTEGER
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_argument: arguments /= Void and then not arguments.is_empty
			valid_weights: a_weights /= Void and then not a_weights.is_empty
			is_valid_aggregate: an_aggregate /= Void and then is_valid_aggregate_value (an_aggregate)
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
			i: INTEGER
		do
			create l_arguments.make_from_array (arguments)
			l_arguments.put_front (arguments.count.out)
			l_arguments.put_front (a_key)
			l_arguments.force (weights)
			from
				i := 1
			until
				i > a_weights.count
			loop
				l_arguments.force (a_weights.at (i))
				i := i + 1
			end
			l_arguments.force (aggregate)
			l_arguments.force (an_aggregate)
			send_command (zunionstore_command, l_arguments)
			Result := read_integer_reply
		end

	zinterstore (a_key: STRING; arguments: ARRAY [STRING]): INTEGER
			--Time complexity: O(N) + O(M log(M)) with N being the sum of the sizes of the input sorted sets,
			--and M being the number of elements in the resulting sorted set
			--Creates a union or intersection of N sorted sets given by keys k1 through kN, and stores it at dstkey.
			--It is mandatory to provide the number of input keys N, before passing the input keys and the other (optional) arguments.
			--As the terms imply, the ZINTERSTORE command requires an element to be present in each of the given inputs
			--to be inserted in the result. The ZUNIONSTORE command inserts all elements across all inputs.
			--Using the WEIGHTS option, it is possible to add weight to each input sorted set.
			--This means that the score of each element in the sorted set is first multiplied by this weight
			--before being passed to the aggregation. When this option is not given, all weights default to 1.
			--With the AGGREGATE option, it's possible to specify how the results of the union or intersection are aggregated.
			--This option defaults to SUM, where the score of an element is summed across the inputs where it exists.
			--When this option is set to be either MIN or MAX, the resulting set will contain the minimum or maximum score of an
			--element across the inputs where it exists.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_argument: arguments /= Void and then not arguments.is_empty
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make_from_array (arguments)
			l_arguments.put_front (arguments.count.out)
			l_arguments.put_front (a_key)
			send_command (zinterstore_command, l_arguments)
			Result := read_integer_reply
		end

	zinterstore_weights (a_key: STRING; arguments: ARRAY [STRING]; a_weights: ARRAY [STRING]): INTEGER
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_argument: arguments /= Void and then not arguments.is_empty
			valid_weights: a_weights /= Void and then not a_weights.is_empty
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
			i: INTEGER
		do
			create l_arguments.make_from_array (arguments)
			l_arguments.put_front (arguments.count.out)
			l_arguments.put_front (a_key)
			l_arguments.force (weights)
			from
				i := 1
			until
				i > a_weights.count
			loop
				l_arguments.force (a_weights.at (i))
				i := i + 1
			end
			send_command (zinterstore_command, l_arguments)
			Result := read_integer_reply
		end

	zinterstore_aggregate (a_key: STRING; arguments: ARRAY [STRING]; an_aggregate: STRING): INTEGER
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_argument: arguments /= Void and then not arguments.is_empty
			is_valid_aggregate: an_aggregate /= Void and then is_valid_aggregate_value (an_aggregate)
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make_from_array (arguments)
			l_arguments.put_front (arguments.count.out)
			l_arguments.put_front (a_key)
			l_arguments.force (aggregate)
			l_arguments.force (an_aggregate)
			send_command (zinterstore_command, l_arguments)
			Result := read_integer_reply
		end

	zinterstore_weights_aggregate (a_key: STRING; arguments: ARRAY [STRING]; a_weights: ARRAY [STRING]; an_aggregate: STRING): INTEGER
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_argument: arguments /= Void and then not arguments.is_empty
			valid_weights: a_weights /= Void and then not a_weights.is_empty
			is_valid_aggregate: an_aggregate /= Void and then is_valid_aggregate_value (an_aggregate)
			if_key_exists_type_is_zset: exists (a_key) implies (type (a_key) ~ type_zset)
		local
			l_arguments: ARRAYED_LIST [STRING]
			i: INTEGER
		do
			create l_arguments.make_from_array (arguments)
			l_arguments.put_front (arguments.count.out)
			l_arguments.put_front (a_key)
			l_arguments.force (weights)
			from
				i := 1
			until
				i > a_weights.count
			loop
				l_arguments.force (a_weights.at (i))
				i := i + 1
			end
			l_arguments.force (aggregate)
			l_arguments.force (an_aggregate)
			send_command (zinterstore_command, l_arguments)
			Result := read_integer_reply
		end

feature -- Redis Commands Operating on HASHES

	hset (a_key: STRING; a_field: STRING; a_value: STRING): INTEGER
			--Time complexity: O(1)
			--Set the specified hash field to the specified value.
			--If key does not exist, a new key holding a hash is created.
			--If the field already exists, and the HSET just produced an update of the value, 0 is returned, otherwise if a new field is created 1 is returned.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			a_field: a_field /= Void
			a_value: a_value /= Void
			if_key_exists_type_is_hash: exists (a_key) implies (type (a_key) ~ type_hash)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (a_field)
			l_arguments.force (a_value)
			send_command (hset_command, l_arguments)
			Result := read_integer_reply
		ensure
			Response: Result = 1 or Result = 0
		end

	hget (a_key: STRING; a_field: STRING): detachable STRING
			--Time complexity: O(1)
			--If key holds a hash, retrieve the value associated to the specified field.
			--If the field is not found or the key does not exist, a special 'nil' value is returned.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_field: a_field /= Void
			if_key_exists_type_is_hash: exists (a_key) implies (type (a_key) ~ type_hash)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_field)
			send_command (hget_command, l_arguments)
			Result := read_bulk_reply
		end

	hsetnx (a_key: STRING; a_field: STRING; a_value: STRING): INTEGER
			--Time complexity: O(1)
			--Set the specified hash field to the specified value, if field does not exist yet.
			--If key does not exist, a new key holding a hash is created.
			--If the field already exists, this operation has no effect and returns 0.
			--Otherwise, the field is set to value and the operation returns 1.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			a_field: a_field /= Void
			a_value: a_value /= Void
			if_key_exists_type_is_hash: exists (a_key) implies (type (a_key) ~ type_hash)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (a_field)
			l_arguments.force (a_value)
			send_command (hsetnx_command, l_arguments)
			Result := read_integer_reply
		ensure
			Response: Result = 1 or Result = 0
		end

	hmset (a_key: STRING; fields_with_values: HASH_TABLE [STRING, STRING])
			--Time complexity: O(N) (with N being the number of fields)
			--Set the respective fields to the respective values. HMSET replaces old values with new values.
			--If key does not exist, a new key holding a hash is created.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_field_with_values: fields_with_values /= Void and then not fields_with_values.is_empty
			if_key_exists_type_is_hash: exists (a_key) implies (type (a_key) ~ type_hash)
		local
			l_arguments: ARRAYED_LIST [STRING]
			l_reply: STRING
		do
			create l_arguments.make (fields_with_values.count * 2)
			l_arguments.force (a_key)
			from
				fields_with_values.start
			until
				fields_with_values.after
			loop
				l_arguments.force (fields_with_values.key_for_iteration)
				l_arguments.force (fields_with_values.item_for_iteration)
				fields_with_values.forth
			end
			send_command (hmset_command, l_arguments)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

	hmget (a_key: STRING; a_fields: ARRAY [STRING]): LIST [detachable STRING]
			--Time complexity: O(N) (with N being the number of fields)
			--Retrieve the values associated to the specified fields.
			--If some of the specified fields do not exist, nil values are returned.
			--Non existing keys are considered like empty hashes.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_fields: a_fields /= Void and then not a_fields.is_empty
			if_key_exists_type_is_hash: exists (a_key) implies (type (a_key) ~ type_hash)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make_from_array (a_fields)
			l_arguments.put_front (a_key)
			send_command (hmget_commmand, l_arguments)
			Result := read_multi_bulk_reply
		end

	hincrby (a_key: STRING; a_field: STRING; a_value: INTEGER_64): INTEGER
			--Time complexity: O(1)
			--Increment the number stored at field in the hash at key by value.
			--If key does not exist, a new key holding a hash is created.
			--If field does not exist or holds a string, the value is set to 0 before applying the operation.
			--The range of values supported by HINCRBY is limited to 64 bit signed integers.
		require
			is_connected: is_connected
			valid_valid: a_key /= Void
			valid_field: a_field /= Void
			if_key_exists_type_is_hash: exists (a_key) implies (type (a_key) ~ type_hash)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (3)
			l_arguments.force (a_key)
			l_arguments.force (a_field)
			l_arguments.force (a_value.out)
			send_command (hincrby_command, l_arguments)
			Result := read_integer_reply
		end

	hexists (a_key: STRING; a_field: STRING): BOOLEAN
			--Time complexity: O(1)
			--Return 1 if the hash stored at key contains the specified field.
			--Return 0 if the key is not found or the field is not present.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_field: a_field /= Void
			if_key_exists_type_is_hash: exists (a_key) implies (type (a_key) ~ type_hash)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_field)
			send_command (hexists_command, l_arguments)
			Result := (read_integer_reply = 1)
		end

	hdel (a_key: STRING; a_field: STRING): INTEGER
			--Time complexity: O(1)
			--Remove the specified field from an hash stored at key.
			--If the field was present in the hash it is deleted and 1 is returned,
			--otherwise 0 is returned and no operation is performed.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			valid_field: a_field /= Void
			if_key_exists_type_is_hash: exists (a_key) implies (type (a_key) ~ type_hash)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (2)
			l_arguments.force (a_key)
			l_arguments.force (a_field)
			send_command (hdel_command, l_arguments)
			Result := read_integer_reply
		end

	hlen (a_key: STRING): INTEGER
			--Time complexity: O(1)
			--Return the number of entries (fields) contained in the hash stored at key.
			--If the specified key does not exist, 0 is returned assuming an empty hash.
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			if_key_exists_type_is_hash: exists (a_key) implies (type (a_key) ~ type_hash)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (hlen_command, l_arguments)
			Result := read_integer_reply
		end

	hgetall (a_key: STRING): LIST [detachable STRING]
			--Time complexity
			--O(N) where N is the size of the hash.
			--Returns all fields and values of the hash stored at key.
			--In the returned value, every field name is followed by its value,
			--so the length of the reply is twice the size of the hash.
			-- TODO: return a hash_table[string,string]
		require
			valid_key: a_key /= Void
			if_key_exists_type_is_hash: exists (a_key) implies (type (a_key) ~ type_hash)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (hgetall_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	hkeys (a_key: STRING): LIST [detachable STRING]
			--Time complexity
			--O(N) where N is the size of the hash.
			--Returns all field names of the hash stored at key.
		require
			valid_key: a_key /= Void
			if_key_exists_type_is_hash: exists (a_key) implies (type (a_key) ~ type_hash)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (hkeys_command, l_arguments)
			Result := read_multi_bulk_reply
		end

	hvals (a_key: STRING): LIST [detachable STRING]
			--Time complexity
			--O(N) where N is the size of the hash.
			--Returns all values of the hash stored at key.
		require
			valid_key: a_key /= Void
			if_key_exists_type_is_hash: exists (a_key) implies (type (a_key) ~ type_hash)
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (1)
			l_arguments.force (a_key)
			send_command (hvals_command, l_arguments)
			Result := read_multi_bulk_reply
		end

feature -- Redis Server Command

	flush_db
			-- Delete all the keys of the currently selected DB.
		require
			is_connected: is_connected
		local
			l_arguments: ARRAYED_LIST [STRING]
			reply: STRING
		do
			create l_arguments.make (0)
			send_command (flush_db_command, l_arguments)
			reply := read_status_reply
			check_reply (reply)
		ensure
				-- redis.db_size = 0
		end

	flush_all
			-- Delete all the keys of all the existing databases, not just the currently selected one.
		require
			is_connected: is_connected
		local
			l_arguments: ARRAYED_LIST [STRING]
			reply: STRING
		do
			create l_arguments.make (0)
			send_command (flush_all_command, l_arguments)
			reply := read_status_reply
			check_reply (reply)
		ensure
				--for all db's redis.db_size = 0
		end

	info: detachable STRING
		require
			is_connected: is_connected
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (0)
			send_command (info_command, l_arguments)
			Result := read_bulk_reply
		end

	bgrewriteaof
			--Rewrites the append-only file to reflect the current dataset in memory.
			--If BGREWRITEAOF fails, no data gets lost as the old AOF will be untouched.
		require
			is_connected: is_connected
		local
			l_arguments: ARRAYED_LIST [STRING]
			l_reply: STRING
		do
			create l_arguments.make (0)
			send_command (bgrewriteaof_command, l_arguments)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

	bgsave
			--Save the DB in background.
			--The OK code is immediately returned.
			--Redis forks, the parent continues to server the clients, the child saves the DB on disk then exit.
			--A client my be able to check if the operation succeeded using the LASTSAVE command.
		require
			is_connected: is_connected
		local
			l_arguments: ARRAYED_LIST [STRING]
			l_reply: STRING
		do
			create l_arguments.make (0)
			send_command (bgsave_command, l_arguments)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

	config_get (a_parameter: STRING): LIST [detachable STRING]
			--Get the value of a configuration parameter
		require
			is_connected: is_connected
			valid_parameter: a_parameter /= Void
		local
			l_argument: ARRAYED_LIST [STRING]
		do
			create l_argument.make (2)
			l_argument.force ("GET")
			l_argument.force (a_parameter)
			send_command (config_get_command, l_argument)
			Result := read_multi_bulk_reply
		end

	config_set (a_parameter: STRING; a_value: STRING)
			--CONFIG SET   parameter value
			--Set a configuration parameter to the given value
		require
			is_connected: is_connected
			valid_parameter: a_parameter /= Void
			valid_value: a_value /= Void
			-- TODO add precondition valid parameter
		local
			l_argument: ARRAYED_LIST [STRING]
			l_reply: STRING
		do
			create l_argument.make (3)
			l_argument.force ("SET")
			l_argument.force (a_parameter)
			l_argument.force (a_value)
			send_command (config_set_command, l_argument)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

	config_resetstat
			--O(1).
			--Resets the statistics reported by Redis using the INFO command.
			--These are the counters that are reset:
			--    * Keyspace hits
			--    * Keyspace misses
			--    * Number of commands processed
			--    * Number of connections received
			--    * Number of expired keys
		require
			is_connected: is_connected
		local
			l_argument: ARRAYED_LIST [STRING]
			l_reply: STRING
		do
			create l_argument.make (1)
			l_argument.force ("RESETSTAT")
			send_command (config_resetstat_command, l_argument)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

	db_size: INTEGER
			-- Return the number of keys in the currently selected database.
		require
			is_connected: is_connected
		local
			l_arguments: ARRAYED_LIST [STRING]
		do
			create l_arguments.make (0)
			send_command (dbsize_command, l_arguments)
			Result := read_integer_reply
		end

	debug_object (a_key: STRING): STRING
			--Get debugging information about a key
		require
			is_connected: is_connected
			valid_key: a_key /= Void
			exists_key: exists (a_key)
		local
			l_argument: ARRAYED_LIST [STRING]
		do
			create l_argument.make (2)
			l_argument.force ("OBJECT")
			l_argument.force (a_key)
			send_command (debug_object_command, l_argument)
			Result := read_status_reply
		end

	debug_segfault
		require
			is_connected: is_connected
		local
			l_argument: ARRAYED_LIST [STRING]
			l_reply: STRING
		do
			create l_argument.make (1)
			l_argument.force ("SEGFAULT")
			send_command (debug_segfault_command, l_argument)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

	lastsave: INTEGER_64
			--Get the UNIX time stamp of the last successful save to disk
		require
			is_connected: is_connected
		local
			l_argument: ARRAYED_LIST [STRING]
		do
			create l_argument.make (0)
			send_command (lastsave_command, l_argument)
			Result := read_integer_reply
		end

	save
			-- Synchronously save the dataset to disk
		require
			is_connected: is_connected
		local
			l_argument: ARRAYED_LIST [STRING]
			l_reply: STRING
		do
			create l_argument.make (0)
			send_command (save_command, l_argument)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

	shutdown
			--Synchronously save the dataset to disk and then shut down the server
		require
			is_connected: is_connected
		local
			l_argument: ARRAYED_LIST [STRING]
			l_reply: STRING
		do
			create l_argument.make (0)
			send_command (shutdown_command, l_argument)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

	slaveof (a_host: STRING; a_port: INTEGER)
			--
		require
			is_connected: is_connected
		local
			l_argument: ARRAYED_LIST [STRING]
			l_reply: STRING
		do
			create l_argument.make (2)
			l_argument.force (a_host)
			l_argument.force (a_port.OUT)
			send_command (slaveof_command, l_argument)
			l_reply := read_status_reply
			check_reply (l_reply)
		end

invariant
	non_empty_description: has_error implies (attached error_description as l_error_description and then (not l_error_description.is_empty))
	socket_valid: socket /= Void

end
