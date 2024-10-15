# frozen_string_literal: true
require 'active_model'
require 'active_support/core_ext'
require 'msgpack'

module AsyncRequestReply
	autoload :MethodsChain, "async_request_reply/methods_chain"
	autoload :Worker, "async_request_reply/worker"
	autoload :Config, "async_request_reply/config"
	require "async_request_reply/repository_adapters/redis_repository_adapter"
	require "async_request_reply/workers_engine/async"
	require "async_request_reply/workers_engine/sidekiq"


	class << self
		include ActiveSupport::Configurable

		def config
			# Default configs
			Config.configure.redis_url_conection ||= 'redis://localhost:6379'
			Config.configure.repository_adapter ||= AsyncRequestReply::RepositoryAdapters::RedisRepositoryAdapter
			Config.configure.async_engine ||= AsyncRequestReply::WorkersEngine::Async
			yield(Config.configure) if block_given?


			Config
		end
	end
end