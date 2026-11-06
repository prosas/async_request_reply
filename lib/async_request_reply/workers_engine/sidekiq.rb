require 'sidekiq'
module AsyncRequestReply
	module WorkersEngine
		class Sidekiq
			include ::Sidekiq::Worker
		  sidekiq_options retry: 4

		  def perform(async_request_id)
				worker = ::AsyncRequestReply::Worker.find(async_request_id)
				worker.perform
			end

			def self.perform_async_at(datetime, async_request_id)
				perform_at(datetime, async_request_id)
			end
		end
	end
end