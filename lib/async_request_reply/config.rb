# frozen_string_literal: true
require 'ostruct'

module AsyncRequestReply
	class Config
		DEFAULTS = {
			repository_adapter: :redis,
			redis_url_conection: 'redis://localhost:6379',
			async_engine: :sidekiq
		}

		@@message_packer_factories = []

		attr_accessor :config

		def initialize
			@config ||= OpenStruct.new
			config.repository_adapter = DEFAULTS[:repository_adapter]
			config.redis_url_conection = DEFAULTS[:redis_url_conection]
			config.async_engine = DEFAULTS[:async_engine]
			super
		end

		def self.instance
			@instance ||= new
		end

		def repository_adapter
			return AsyncRequestReply::RepositoryAdapters::RedisRepositoryAdapter if config.repository_adapter == :redis
			config.repository_adapter
		end

		def redis_url_conection
			config.redis_url_conection
		end

		def async_engine
			return AsyncRequestReply::WorkersEngine::Async if config.async_engine   == :async
			return AsyncRequestReply::WorkersEngine::Sidekiq if config.async_engine == :sidekiq

			config.async_engine
		end

		def message_packer_factories
			@@message_packer_factories
		end

		def add_message_pack_factory
			factory = {first_byte: nil, klass: nil, packer: nil, unpacker: nil}
			@@message_packer_factories.push(yield(factory))
		end
	end
end
