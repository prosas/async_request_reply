# frozen_string_literal: true

module AsyncRequestReply
	module Configs
		class Configuration
			include Singleton
			include ActiveSupport::Configurable
		end
	end
end