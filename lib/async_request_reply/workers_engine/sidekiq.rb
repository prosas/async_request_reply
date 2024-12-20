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
		end
	end
end