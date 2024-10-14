# frozen_string_literal: true
require "async_request_reply/configs/configuration"
require "async_request_reply/configs/configured"

module AsyncRequestReply
	class Config
		include Singleton

		def self.configured
			instance.configured
		end

		def self.configure
			instance.configure
		end

		def configure
			AsyncRequestReply::Configs::Configuration.instance.config
		end

		def configured
			AsyncRequestReply::Configs::Configured.instance
		end
	end
end
