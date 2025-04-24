require 'minitest/autorun'
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

  let(:work1) { AsyncRequestReply::Worker.new({ class_instance: 1, methods_chain: [[:+, 1], [:*, 2]] }) }
  let(:work2) { AsyncRequestReply::Worker.new({ class_instance: 2, methods_chain: [[:*, 2], [:+, 2]] }) }
  let(:work3_error) { AsyncRequestReply::Worker.new({ class_instance: 2, methods_chain: [[:*, 2], [:+, 2], [:/, 0]] }) }
  let(:worker_in_batch) { AsyncRequestReply::WorkerInBatch.new([work1, work2]) }

  before do
    AsyncRequestReply.configure do |conf|
      conf.add_message_pack_factory do |factory|
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
  end

  describe 'meta_data' do
    it 'should save meta_data' do
      worker_in_batch = AsyncRequestReply::WorkerInBatch.new
      worker_in_batch.meta = { 'redirect_url': 'url' }
      worker_in_batch.save
      _(AsyncRequestReply::WorkerInBatch.find(worker_in_batch.id).meta['redirect_url']).must_equal 'url'
    end
  end

  describe '.find' do
    it 'should find work' do
      worker_in_batch = AsyncRequestReply::WorkerInBatch.new
      worker_in_batch.workers = [work1]
      worker_in_batch.save
      _(AsyncRequestReply::WorkerInBatch.find(worker_in_batch.id).id).must_equal worker_in_batch.id
    end
  end

  describe '.find!' do
    it 'should raise exception case not found' do
      assert_raises AsyncRequestReply::WorkerInBatch::WorkerInBatchNotFound do
        worker_in_batch = AsyncRequestReply::WorkerInBatch.new
        worker_in_batch.workers = [work1]
        worker_in_batch.save
        AsyncRequestReply::WorkerInBatch.find!('not_found')
      end
    end
  end

  describe '.perform' do

    it 'Using with Fibonacci' do
      worker1 = AsyncRequestReply::Worker.new({ class_instance: Fibonacci.new, methods_chain: [[:sequence, 35]] })
      worker2 = AsyncRequestReply::Worker.new({ class_instance: Fibonacci.new, methods_chain: [[:sequence, 35]] })
      batch = AsyncRequestReply::WorkerInBatch.new
      batch.workers = [worker1, worker2]
      batch.save
      batch = AsyncRequestReply::WorkerInBatch.find(batch.id)
      _(batch.perform)
      batch = AsyncRequestReply::WorkerInBatch.find(batch.id)
      _(batch.worker_ids.count).must_equal 2
      _(batch.start_time).wont_be_nil
      _(batch.end_time).wont_be_nil
      _(batch.elapsed).wont_be_nil
    end

    it 'Using with error' do
      batch = AsyncRequestReply::WorkerInBatch.new
      batch.workers = [work3_error, work1, work2]
      batch.save
      batch = AsyncRequestReply::WorkerInBatch.find(batch.id)
      _(batch.perform)
      batch = AsyncRequestReply::WorkerInBatch.find(batch.id)
      _(batch.worker_ids.count).must_equal 3
      _(batch.start_time).wont_be_nil
      _(batch.end_time).wont_be_nil
      _(batch.elapsed).wont_be_nil
      _(batch.successes.count).must_equal 2
      _(batch.failures.count).must_equal 1
    end
  end

  it '.perform_async' do
    worker1 = AsyncRequestReply::Worker.new({ class_instance: Fibonacci.new, methods_chain: [[:sequence, 35]] })
    worker2 = AsyncRequestReply::Worker.new({ class_instance: Fibonacci.new, methods_chain: [[:sequence, 35]] })
    batch = AsyncRequestReply::WorkerInBatch.new
    batch.workers = [worker1, worker2]
    batch.save
    batch = AsyncRequestReply::WorkerInBatch.find(batch.id)
    _(batch.perform_async)
  end
end
