# frozen_string_literal: true

# Defines interface that lib will use
# for access the configuration that
# client defined
module AsyncRequestReply
	module Configs
		class Configured
			include Singleton

			def redis_url_conection
				AsyncRequestReply::Config.configure.redis_url_conection
			end

			def repository_adapter
				AsyncRequestReply::Config.configure.repository_adapter
			end

			def async_engine
				return AsyncRequestReply::WorkersEngine::Sidekiq if AsyncRequestReply::Config.configure.async_engine == :sidekiq
				return AsyncRequestReply::WorkersEngine::Async if AsyncRequestReply::Config.configure.async_engine == :async

				AsyncRequestReply::Config.configure.async_engine
			end
		end
	end
end