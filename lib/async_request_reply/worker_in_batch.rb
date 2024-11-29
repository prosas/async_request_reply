module AsyncRequestReply
	class WorkerInBatch
		attr_reader :worker_ids, :uuid

		ONE_HOUR = 60*60
	  LIVE_TIMEOUT = ONE_HOUR # TODO-2023-10-22: Isso limita o processamento de máximo 1 hora.

		@@config = AsyncRequestReply::Config.instance

		def initialize(uuid = nil)
			@uuid = new_record?(uuid) ? "async_request_in_batch:#{SecureRandom.uuid}" : uuid
		end

		def new_record?(p_uuid)
			return true if p_uuid.nil?

			@@config.repository_adapter.get(p_uuid).nil?
		end

		def workers=(workers)
			workers.map(&:save)
			@worker_ids = workers.map(&:uuid)
		end

		def workers
			@worker_ids.map{|id| AsyncRequestReply::Worker.find(id)}
		end

		def self.find(p_uuid)
			resource = _find(p_uuid)
			return nil if resource.empty?

			instance = new(resource)
			instance.workers = resource["worker_ids"].map{|id| AsyncRequestReply::Worker.find(id)}
			instance
		end

		def self._find(p_uuid)
	    resource = @@config.repository_adapter.get(p_uuid)
	    return nil unless resource

	    JSON.parse(resource)
	  end

		def id
	    uuid
	  end

	  def uuid
	  	@uuid
	  end

		def save
			#TODO-2024-11-27: Decide serializer a classe usando json
			# já que a classe não vai salvar um objeto complexo. Avaliar em versões futuras
			# se adotamos messager_packer ou desacopla o messager_packer e aplica uma
			# estratégia de mudança das implementações para cada caso.
	    @@config.repository_adapter.setex(uuid, LIVE_TIMEOUT, as_json.to_json)
	  end

	  def total
	  	workers.count
	  end

	  def processed
	  	successes + failures
	  end

	  def processing
	  	workers.select{|worker| worker.status == "processing" }
	  end

		def successes
			workers.select{|worker| worker.status == "done" }
		end

		def failures
			workers.select{|worker| worker.status == "unprocessable_entity" || worker.status == "internal_server_error"}
		end

		def start_time
			workers.map(&:start_time).compact.sort.first
		end

		def end_time
			times = workers.map(&:end_time)
			return nil if times.include?(nil)
			times.sort.last
		end

		def elapsed
			return nil unless start_time
			(end_time || Process.clock_gettime(Process::CLOCK_MONOTONIC)) - start_time
		end

		def perform
			workers.map(&:perform_async)
		end

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
	end
end