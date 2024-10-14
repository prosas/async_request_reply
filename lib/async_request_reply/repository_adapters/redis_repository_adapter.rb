# frozen_string_literal: true
require_relative '../config'
require_relative 'abstract_repository_adapter'
require "redis"

module AsyncRequestReply
	module RepositoryAdapters
		class RedisRepositoryAdapter < AbstractRepositoryAdapter
			class << self
				@@redis ||= Redis.new(url: AsyncRequestReply::Config.configured.redis_url_conection)

				def get(uuid)
					@@redis.get(uuid)
				end

				def del(uuid)
					@@redis.del(uuid)
				end

				def setex(uuid, ttl, payload)
					@@redis.setex(uuid, ttl, payload)
				end
			end
		end
	end
end