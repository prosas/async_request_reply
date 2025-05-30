# frozen_string_literal: true
require 'ostruct'
require 'logger'

module AsyncRequestReply
  class Config
    DEFAULTS = {
      repository_adapter: :io,
      redis_url_conection: 'redis://localhost:6379',
      async_engine: :simple_thread_pool,
      logger: Logger.new(STDOUT)
    }

    @@message_packer_factories = []

    attr_accessor :config

    def initialize
      @config ||= OpenStruct.new
      config.repository_adapter = DEFAULTS[:repository_adapter]
      config.redis_url_conection = DEFAULTS[:redis_url_conection]
      config.async_engine = DEFAULTS[:async_engine]
      config.logger = DEFAULTS[:logger]
      super
    end

    def self.instance
      @instance ||= new
    end

    def configure
      yield(self)
    end

    def repository_adapter
      return AsyncRequestReply::RepositoryAdapters::RedisRepositoryAdapter if config.repository_adapter == :redis
      return AsyncRequestReply::RepositoryAdapters::IORepositoryAdapter if config.repository_adapter == :io
      config.repository_adapter
    end

    def redis_url_conection
      config.redis_url_conection
    end

    def async_engine
      return AsyncRequestReply::WorkersEngine::SimpleThreadPool if config.async_engine   == :simple_thread_pool
      return AsyncRequestReply::WorkersEngine::Sidekiq if config.async_engine == :sidekiq

      config.async_engine
    end

    def async_engine=(value)
      config.async_engine = value
    end

    def repository_adapter=(value)
      config.repository_adapter = value
    end

    def redis_url_conection=(value)
      config.redis_url_conection = value
    end

    def logger
      config.logger
    end

    def message_packer_factories
      @@message_packer_factories
    end

    def add_message_pack_factory
      factory = yield({first_byte: nil, klass: nil, packer: nil, unpacker: nil})
      factory[:klass].class_eval do
        def as_json
          self
        end
      end
      @@message_packer_factories.push(factory)
    end
  end
end
