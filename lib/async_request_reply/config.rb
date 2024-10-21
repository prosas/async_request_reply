# frozen_string_literal: true
require "async_request_reply/configs/configuration"
require "async_request_reply/configs/configured"

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
	end
end
