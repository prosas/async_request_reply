require 'async'
module AsyncRequestReply
	module WorkersEngine
		class Async
			class << self
				def perform_async(id)
					worker = ::AsyncRequestReply::Worker.find(id)
					Async do
						worker.perform
					end
				end
			end
		end
	end
end