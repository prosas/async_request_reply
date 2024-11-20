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
			worker = AsyncRequestReply::Worker.new({ class_instance: Fibonacci.new, methods_chain: [[:sequence, 35]]})
			in_batch = AsyncRequestReply::WorkerInBatch.new([worker])
		end
	end
end