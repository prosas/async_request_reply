require 'async'
module AsyncRequestReply
	module WorkersEngine
		class Async
			class << self
				def perform_async(id)
					worker = ::AsyncRequestReply::Worker.find(id)
					puts worker.inspect
					Async do
						worker.perform
					end
				end
			end
		end
	end
end