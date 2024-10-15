module AsyncRequestReply
	module RepositoryAdapters
		class AbstractRepositoryAdapter
			class << self
				def get(uuid)
					raise NotImplementedError
				end
				def del(uuid)
					raise NotImplementedError
				end
				def setex(uuid, ttl, payload)
					raise NotImplementedError
				end
			end
		end
	end
end