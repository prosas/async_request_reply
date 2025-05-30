# frozen_string_literal: true
require 'msgpack'
require 'active_support'
require 'active_support/core_ext'

module AsyncRequestReply
	autoload :Config, "async_request_reply/config"
	autoload :MethodsChain, "async_request_reply/methods_chain"
	autoload :Worker, "async_request_reply/worker"
	autoload :WorkerInBatch, "async_request_reply/worker_in_batch"
	require "async_request_reply/repository_adapters/redis_repository_adapter"
	require "async_request_reply/repository_adapters/i_o_repository_adapter"
	require "async_request_reply/workers_engine/sidekiq"
	require "async_request_reply/workers_engine/simple_thread_pool"

	# Load default configs
	AsyncRequestReply::Config.instance

	def self.configure(&block)
		config.configure(&block)
	end

	def self.config
		AsyncRequestReply::Config.instance
	end
end