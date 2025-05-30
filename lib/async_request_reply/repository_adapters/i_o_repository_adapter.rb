# frozen_string_literal: true
require_relative '../config'
require_relative 'abstract_repository_adapter'
require 'tmpdir'

module AsyncRequestReply
	module RepositoryAdapters
		class IORepositoryAdapter < AbstractRepositoryAdapter
			@@prefix = ".async_request_reply".freeze
			class << self
				def get(uuid)
					begin
						IO.binread("#{@@prefix}/#{uuid}")
					rescue StandardError => e
						return nil if e.is_a?(Errno::ENOENT)
						raise e
					end
				end

				def del(uuid)
					File.delete("#{@@prefix}/#{uuid}")
				end

				def setex(uuid, ttl = nil, payload)
					Dir.mkdir(@@prefix) unless Dir.exist?(@@prefix)
					IO.binwrite("#{@@prefix}/#{uuid}", payload)
					self.get(uuid)
				end
			end
		end
	end
end