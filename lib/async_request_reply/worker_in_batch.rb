# AsyncRequestReply::WorkerInBatch - [Made for gpt]
#
# This class represents a batch of workers processing asynchronous requests.
# It manages worker records, tracks their status, and provides methods to
# manipulate and query the workers in the batch.
#
# Attributes:
# - `worker_ids` [Array<String>] The UUIDs of the workers in this batch.
# - `uuid` [String] The unique identifier for the batch.

module AsyncRequestReply
  class WorkerInBatch
    # @private
     class WorkerInBatchNotFound < StandardError
      attr_accessor :uuid

      def initialize(uuid)
        @uuid = uuid
        super
      end

      def message
        "WorkerInBatch not found with id #{@uuid}"
      end
    end

    # The worker UUIDs associated with this batch.
    # @return [Array<String>] an array of worker UUIDs.
    attr_accessor :meta, :worker_ids, :uuid, :processing, :waiting, :successes, :failures, :start_time, :end_time

    # @private
    ONE_HOUR = 3600

    # @private
    LIVE_TIMEOUT = ONE_HOUR

    # @private
    @@config = AsyncRequestReply::Config.instance

    # Initializes a new batch of workers with an optional UUID.
    #
    # If a UUID is not provided or the UUID is invalid, a new UUID is generated.
    #
    # @param uuid [String, nil] The UUID of the batch. If nil, a new UUID is generated.
    def initialize(uuid = nil)
      @worker_ids = []
      @meta = {}
      @uuid = new_record?(uuid) ? "async_request_in_batch:#{SecureRandom.uuid}" : uuid

      @waiting = []
      @processing = []
      @failures = []
      @successes = []
    end


    # Assigns workers to the batch.
    #
    # The workers are saved, and their UUIDs are stored in the batch.
    #
    # @param workers [Array<AsyncRequestReply::Worker>] The workers to assign to the batch.
    def workers=(workers)
      workers.map do |worker|
        worker.save
        @worker_ids << worker.uuid
      end
    end

    # Finds a `WorkerInBatch` by its UUID raise exception case not found.
    #
    # @param p_uuid [String] The UUID of the batch to find.
    # @return [AsyncRequestReply::WorkerInBatch, nil] The found batch or nil if not found.
    def self.find!(p_uuid)
      resource = find(p_uuid)
      raise(WorkerInBatchNotFound, p_uuid) unless resource
      resource
    end

    # Finds a `WorkerInBatch` by its UUID.
    #
    # @param p_uuid [String] The UUID of the batch to find.
    # @return [AsyncRequestReply::WorkerInBatch, nil] The found batch or nil if not found.
    def self.find(p_uuid)
      resource = _find(p_uuid)
      return nil unless resource

      instance = new(resource['uuid'])
      instance.worker_ids = resource['worker_ids']
      instance.start_time = resource['start_time']
      instance.end_time = resource['end_time']
      instance.worker_ids = resource['worker_ids']
      instance.waiting = resource['waiting']
      instance.processing = resource['processing']
      instance.failures = resource['failures']
      instance.successes = resource['successes']
      instance.meta = resource["meta"]
      instance
    end


    # Returns the UUID of the batch.
    #
    # @return [String] The UUID of the batch.
    def id
      uuid
    end

    # Returns the UUID of the batch.
    #
    # @return [String] The UUID of the batch.
    def uuid
      @uuid
    end

    # Saves the current state of the batch to the repository.
    #
    # The batch data is serialized to JSON and stored in the repository with an
    # expiration time of 1 hour.
    #
    # @return [void]
    def save
      # TODO-2024-11-27: Decide serializer strategy (e.g., json, message_packer).
      @@config.repository_adapter.setex(uuid, LIVE_TIMEOUT, as_json.to_json)
    end

    # Returns the total number of workers in the batch.
    #
    # @return [Integer] The total count of workers in the batch.
    def total
      worker_ids.count
    end

    # Returns the number of processed workers (successes + failures).
    #
    # @return [Integer] The number of processed workers.
    def processed
      @successes + @failures
    end

    # Returns the elapsed time for the batch.
    #
    # The elapsed time is the difference between the start time and end time.
    # If the end time is unavailable, the current process time is used.
    #
    # @return [Float, nil] The elapsed time in seconds or nil if start time is unavailable.
    def elapsed
      return nil unless @start_time
      (@end_time || Process.clock_gettime(Process::CLOCK_MONOTONIC)) - @start_time
    end

    # Starts the asynchronous processing of all workers in the batch.
    #
    # @return [void]
    def perform
      # TODO: Add concurrency model.
      @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      save
      @waiting = worker_ids.dup
      @waiting.size.times do
        @processing.push(@waiting.pop)
        save
        worker_id = @processing.last
        worker = AsyncRequestReply::Worker.find(worker_id)
        worker.perform
        worker.reload!
        @failures.push(@processing.pop) if ["unprocessable_entity", "internal_server_error"].include?(worker.status)
        @successes.push(@processing.pop)
        save
      end

      @end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      save
    end

    def perform_async
      save
      AsyncRequestReply::Worker.new(class_instance: AsyncRequestReply::WorkerInBatch, methods_chain: [[:find, id],[:perform]]).perform_async
    end

    # Returns a JSON representation of the batch.
    #
    # @return [Hash] The JSON-compatible representation of the batch.
    def as_json
      {
        uuid: @uuid,
        start_time: @start_time,
        end_time: @end_time,
        worker_ids: @worker_ids,
        waiting: @waiting,
        qtd_waiting: @waiting.count,
        processing: @processing,
        qtd_processing: @processing.count,
        failures: @failures,
        qtd_fail: @failures.count,
        successes: @successes,
        qtd_success: @successes.count,
        meta: @meta,
        qtd_processed: processed.count,
        total: total
      }
    end

    private
    # Helper method to retrieve batch data from the repository.
    #
    # @param p_uuid [String] The UUID of the batch.
    # @return [Hash, nil] The parsed JSON resource or nil if not found.
    def self._find(p_uuid)
      resource = @@config.repository_adapter.get(p_uuid)
      return nil unless resource
      JSON.parse(resource)
    end
    # Checks if the given UUID is new (i.e., not present in the repository).
    #
    # @param p_uuid [String, nil] The UUID to check.
    # @return [Boolean] True if the UUID is new, false otherwise.
    def new_record?(p_uuid)
      return true if p_uuid.nil?
      @@config.repository_adapter.get(p_uuid).nil?
    end
  end
end
