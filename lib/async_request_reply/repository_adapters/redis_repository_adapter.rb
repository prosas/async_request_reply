# frozen_string_literal: true
require_relative '../config'
require_relative 'abstract_repository_adapter'
require 'redis-client'

module AsyncRequestReply
	module RepositoryAdapters
		class RedisRepositoryAdapter < AbstractRepositoryAdapter
			class << self
				def get(uuid)
					client.call("GET", uuid)
				end

				def del(uuid)
					client.call("DEL", uuid)
				end

				def setex(uuid, ttl, payload)
					raise "Redis can`t save key #{uuid}" unless client.call("SET", uuid, payload, ex: ttl)
					get(uuid)
				end

				def client
					#TODO: ADD CONFIGURATION timeout and size of pool
					@@redis ||= RedisClient.config(url: AsyncRequestReply::Config.instance.redis_url_conection).new_pool(timeout: 0.5, size: 5) 
				end
			end
		end
	end
end