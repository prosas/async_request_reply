require "minitest/autorun"
require 'async_request_reply'
require 'byebug'

describe AsyncRequestReply::WorkerInBatch do
	# Feito pelo GPT
	
	class Fibonacci
	  attr_accessor :sequence_cache

	  def initialize
	    @sequence_cache = {}
	  end

	  # Método para calcular Fibonacci recursivamente
	  def recursive(n)
	    return n if n <= 1
	    recursive(n - 1) + recursive(n - 2)
	  end

	  # Método para gerar a sequência até o enésimo número
	  def sequence(up_to)
	    (0..up_to).map { |n| @sequence_cache[n] ||= recursive(n) }
	  end
	end


	let(:work1) { AsyncRequestReply::Worker.new({ class_instance: 1, methods_chain: [[:+, 1], [:*, 2]]}) }
	let(:work2) { AsyncRequestReply::Worker.new({ class_instance: 2, methods_chain: [[:*, 2], [:+, 2]]}) }
	let(:work3_erro) { AsyncRequestReply::Worker.new({ class_instance: 2, methods_chain: [[:*, 2], [:+, 2], [:/, 0]]}) }
	let(:worker_in_batch) { AsyncRequestReply::WorkerInBatch.new([work1,work2]) } 

	describe '.perform' do
		before do
			AsyncRequestReply::Config.configure.add_message_pack_factory do |factory|
				factory[:first_byte] = 0x09
				factory[:klass] = Fibonacci
				factory[:packer] = lambda { |instance, packer|
	      	packer.write_string(instance.sequence_cache.to_json)
	      }
				factory[:unpacker] = lambda { |unpacker|
	        data = unpacker.read
	        instance = Fibonacci.new
	        instance.sequence_cache = JSON.parse(data)
	        instance
	      }
	      factory
			end
		end
		# describe 'with all works successfully' do
		# 	before do
		# 		@worker_in_batch = AsyncRequestReply::WorkerInBatch.new([work1,work2])
		# 		@worker_in_batch.perform
		# 	end

		# 	it { _(@worker_in_batch.workers.count).must_equal 2 }
		# 	it { _(@worker_in_batch.successes.count).must_equal 2 }
		# 	it { _(@worker_in_batch.failures.count).must_equal 0 }
		# end
		# describe 'with some works failures' do
		# 	before do
		# 		@worker_in_batch = AsyncRequestReply::WorkerInBatch.new([work1,work2,work3_erro])
		# 		@worker_in_batch.perform
		# 	end

		# 	it { _(@worker_in_batch.workers.count).must_equal 3 }
		# 	it { _(@worker_in_batch.successes.count).must_equal 2 }
		# 	it { _(@worker_in_batch.failures.count).must_equal 1 }
		# end

		it 'Using with Fibonacci' do
			worker1 = AsyncRequestReply::Worker.new({ class_instance: Fibonacci.new, methods_chain: [[:sequence, 35]]})
			worker2 = AsyncRequestReply::Worker.new({ class_instance: Fibonacci.new, methods_chain: [[:sequence, 35]]})

			batch = AsyncRequestReply::WorkerInBatch.new
			batch.workers = [worker1, worker2]
			batch.save
			batch = AsyncRequestReply::WorkerInBatch.find(batch.id)
			_(batch.perform)
			_(batch.workers.count).must_equal 2
			_(batch.start_time)
			_(batch.end_time)
			_(batch.elapsed)
		end
	end
end