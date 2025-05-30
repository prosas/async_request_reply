module AsyncRequestReply
	module WorkersEngine
		class SimpleThreadPool
			MAX_THREADS = 2
			@@jobs = Queue.new
			@@workers = Array.new(MAX_THREADS) do
				Thread.new do
					loop do
						job = @@jobs.pop
						job.perform
					end
				end
			end
			
			def self.perform_async(async_request_id)
				@@jobs.push(::AsyncRequestReply::Worker.find(async_request_id))
			end
		end
	end
end