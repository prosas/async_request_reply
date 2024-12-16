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
    # The worker UUIDs associated with this batch.
    # @return [Array<String>] an array of worker UUIDs.
    attr_reader :worker_ids, :uuid

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

    # @private
    ONE_HOUR = 60 * 60 

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
      @uuid = new_record?(uuid) ? "async_request_in_batch:#{SecureRandom.uuid}" : uuid
    end


    # Assigns workers to the batch.
    #
    # The workers are saved, and their UUIDs are stored in the batch.
    #
    # @param workers [Array<AsyncRequestReply::Worker>] The workers to assign to the batch.
    def workers=(workers)
      workers.map(&:save)
      @worker_ids = workers.map(&:uuid)
    end

    # Returns the workers associated with this batch.
    #
    # @return [Array<AsyncRequestReply::Worker>] The list of workers in the batch.
    def workers
      @worker_ids.map { |id| AsyncRequestReply::Worker.find(id) }
    end

    # Finds a `WorkerInBatch` by its UUID raise exception case not found.
    #
    # @param p_uuid [String] The UUID of the batch to find.
    # @return [AsyncRequestReply::WorkerInBatch, nil] The found batch or nil if not found.
    def self.find!(p_uuid)
      resource = find(p_uuid)
      raise(WorkerInBatchNotFound, p_uuid) unless resource
    end

    # Finds a `WorkerInBatch` by its UUID.
    #
    # @param p_uuid [String] The UUID of the batch to find.
    # @return [AsyncRequestReply::WorkerInBatch, nil] The found batch or nil if not found.
    def self.find(p_uuid)
      resource = _find(p_uuid)
      return nil unless resource

      instance = new(resource['uuid'])
      instance.workers = resource["worker_ids"].map { |id| AsyncRequestReply::Worker.find(id) }
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
      workers.count
    end

    # Returns the number of processed workers (successes + failures).
    #
    # @return [Integer] The number of processed workers.
    def processed
      successes + failures
    end

    # Returns the workers that are currently being processed.
    #
    # @return [Array<AsyncRequestReply::Worker>] The workers with "processing" status.
    def processing
      workers.select { |worker| worker.status == "processing" }
    end

    # Returns the workers that have successfully completed processing.
    #
    # @return [Array<AsyncRequestReply::Worker>] The workers with "done" status.
    def successes
      workers.select { |worker| worker.status == "done" }
    end

    # Returns the workers that have failed processing.
    #
    # @return [Array<AsyncRequestReply::Worker>] The workers with "unprocessable_entity" or "internal_server_error" status.
    def failures
      workers.select { |worker| worker.status == "unprocessable_entity" || worker.status == "internal_server_error" }
    end

    # Returns the start time of the batch based on the earliest worker start time.
    #
    # @return [Float, nil] The earliest worker's start time or nil if not available.
    def start_time
      workers.map(&:start_time).compact.sort.first
    end

    # Returns the end time of the batch based on the latest worker end time.
    #
    # @return [Float, nil] The latest worker's end time or nil if not available.
    def end_time
      times = workers.map(&:end_time)
      return nil if times.include?(nil)
      times.sort.last
    end

    # Returns the elapsed time for the batch.
    #
    # The elapsed time is the difference between the start time and end time.
    # If the end time is unavailable, the current process time is used.
    #
    # @return [Float, nil] The elapsed time in seconds or nil if start time is unavailable.
    def elapsed
      return nil unless start_time
      (end_time || Process.clock_gettime(Process::CLOCK_MONOTONIC)) - start_time
    end

    # Starts the asynchronous processing of all workers in the batch.
    #
    # @return [void]
    def perform
      workers.map(&:perform_async)
    end

    # Returns a JSON representation of the batch.
    #
    # @return [Hash] The JSON-compatible representation of the batch.
    def as_json
      {
        uuid: @uuid,
        worker_ids: @worker_ids,
        qtd_processing: processing.count,
        qtd_processed: processed.count,
        qtd_success: successes.count,
        qtd_fail: failures.count,
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
