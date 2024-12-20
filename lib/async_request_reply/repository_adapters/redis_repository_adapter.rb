# frozen_string_literal: true
require_relative '../config'
require_relative 'abstract_repository_adapter'
require "redis"

module AsyncRequestReply
	module RepositoryAdapters
		class RedisRepositoryAdapter < AbstractRepositoryAdapter
			class << self
				def get(uuid)
					client.get(uuid)
				end

				def del(uuid)
					client.del(uuid)
				end

				def setex(uuid, ttl, payload)
					client.setex(uuid, ttl, payload)
				end

				def client
					@@redis ||= Redis.new(url: AsyncRequestReply::Config.instance.redis_url_conection)
				end
			end
		end
	end
end