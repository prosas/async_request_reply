# frozen_string_literal: true
require 'msgpack'

module AsyncRequestReply
	autoload :Config, "async_request_reply/config"
	autoload :MethodsChain, "async_request_reply/methods_chain"
	autoload :Worker, "async_request_reply/worker"
	require "async_request_reply/repository_adapters/redis_repository_adapter"
	require "async_request_reply/workers_engine/async"
	require "async_request_reply/workers_engine/sidekiq"

	# Load default configs
	AsyncRequestReply::Config.instance

	def self.config
		AsyncRequestReply::Config.instance
	end
end