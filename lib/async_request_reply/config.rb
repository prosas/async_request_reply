# frozen_string_literal: true

module AsyncRequestReply
	class Config
		include ActiveSupport::Configurable
		DEFAULTS = {
			repository_adapter: :redis,
			redis_url_conection: 'redis://localhost:6379',
			async_engine: RUBY_VERSION.to_i >= 3 ? :async : :sidekiq
		}

		def initialize
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
	end
end
