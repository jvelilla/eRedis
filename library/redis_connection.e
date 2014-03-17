note
	description: "Summary description for {REDIS_CONNECTION}."
	author: ""
	date: "$Date$"
	revision: "$Revision$"

class
	REDIS_CONNECTION

inherit

	NETWORK_CLIENT

create
	make_client

feature

	make_client
		local
			l_in_out: detachable like in_out
		do
			make (port, host)
			l_in_out := in_out
				--			send (our_list)
				--			receive
				--			process_received
				--			cleanup
		rescue
			if l_in_out /= Void and then not l_in_out.is_closed then
				l_in_out.close
			end
		end

	ping
		do
			send ("+PING%R%N")
		end

feature -- Connection

	host: STRING = "localhost"

	port: INTEGER = 6379

end
