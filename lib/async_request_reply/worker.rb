# frozen_string_literal: true
require_relative 'config'
require_relative 'methods_chain'

module AsyncRequestReply
	class Worker
		# TODO-2023-10-22: Adicinar mais logs a classe.

  	@@config = AsyncRequestReply::Config.instance

	  STATUS = %i[waiting processing done unprocessable_entity internal_server_error]
	  ONE_HOUR = 60*60
	  LIVE_TIMEOUT = ONE_HOUR # TODO-2023-10-22: Isso limita o processamento de máximo 1 hora.

	  attr_accessor :status, :uuid, :status_url, :redirect_url,
	                :class_instance, :methods_chain, :success,
	                :redirect_url, :failure, :_ttl
	  attr_reader :new_record, :errors, :start_time, :end_time

	  def initialize(attrs = {})
	    attrs.transform_keys(&:to_sym)
	    @uuid = new_record?(attrs[:uuid]) ? "async_request:#{SecureRandom.uuid}" : attrs[:uuid]

	    # INFO: Remover do repositório depois que async_request for processado
	    # TODO-2023-10-22: Entender a relação entre número de objetos criados e
	    # consulmo de mémoria no host onde está o redis. Definir uma estrátegia
	    # que limite o tamanho máximo de uma instância da classe e controle do ciclo
	    # de vida de cada instancia no banco pra ofecer melhor controle pra cada caso
	    # de uso.
	    destroy(30.seconds.to_i) if !new_record?(attrs[:uuid]) && attrs[:status].to_sym == :done

	    # Assigners attributes
	    assign_attributes(default_attributes.merge(attrs))
	  end

	  def valid?
	  	@errors = []
	  	@errors << "class_instance can't be blank." if class_instance.nil?

	  	@errors.empty?
	  end

	  def attributes
	    { 'uuid' => uuid,
	      'status' => status,
	      'success' => success,
	      'failure' => failure,
	      'methods_chain' => methods_chain,
	      'class_instance' => class_instance,
	      'redirect_url' => redirect_url,
	      'start_time' => start_time,
	      'end_time' => end_time
	    }
	  end

	  def default_attributes
	    {
	    	methods_chain: [],
	      'status' => :waiting,
	      success: {
	      	class_instance: 'self',
	      	methods_chain: []
	      },
	      failure: {
	      	class_instance: 'self',
	      	methods_chain: []
	      }
	    }
	  end

	  def new_record?(p_uuid)
	    return true if p_uuid.nil?

	    @@config.repository_adapter.get(p_uuid).nil?
	  end

	  def id
	    uuid
	  end

	  def self.find(p_uuid)
	    resource = _find(p_uuid)
	    return nil if resource.empty?

	    new(resource)
	  end

	  def self._find(p_uuid)
	    resource = @@config.repository_adapter.get(p_uuid)
	    return nil unless resource

	    unpack(resource)
	  end

	  def elapsed
			(@end_time || Process.clock_gettime(Process::CLOCK_MONOTONIC)) - @start_time
		end


	  def update(attrs)
	    assign_attributes(attrs)
	    save
	  end

	  def reload!
	  	assign_attributes(self.class._find(self.uuid))
	  end

	  ##
	  # Remove request from data store. Can pass as params 
	  # integer value for how many seconds you want remove
	  # from data store
	  def destroy(seconds_in = 0.seconds.to_i)
	    return @@config.repository_adapter.del(id) if seconds_in.zero?

	    self._ttl = seconds_in
	    save
	  end

	  def save
	  	return nil unless valid?
	    attributes = self.class.unpack(@@config.repository_adapter.setex(uuid, (_ttl || LIVE_TIMEOUT), to_msgpack))
	    assign_attributes(attributes)
	  end

	  def perform_async
	  	save
	  	@@config.async_engine.perform_async(id)
	  end

	  # Serializa a intância usando o MessagePack.
	  # Além de ser mais rápido e menor que JSON
	  # é uma boa opção para serializar arquivos.
	  # Ref.: https://msgpack.org/
	  # Ref.: https://github.com/msgpack/msgpack-ruby#extension-types
	  def to_msgpack
	    self.class.message_pack_factory.dump(attributes.as_json)
	  end

	  def self.unpack(packer)
	    message_pack_factory.load(packer)
	  end

	  # TODO: Desacoplar message pack factory
	  def self.message_pack_factory
	    factory = MessagePack::Factory.new

	  	@@config.message_packer_factories.each do |fac|
	  		factory.register_type(
	  			fac[:first_byte],
	  			fac[:klass],
	  			packer: fac[:packer],
	  			unpacker: fac[:unpacker],
	  			recursive: true
	  			)
	  	end

	    factory
	  end

	  def success
	    # TODO-2023-10-22: Entender em que momento do ciclo de vida
	    # do objeto que esse atributo é nil pra corrigir o problema
	    # corretamente.
	    @success&.transform_keys(&:to_sym)
	  end

	  def failure
	    # TODO-2023-10-22: Entender em que momento do ciclo de vida
	    # do objeto que esse atributo é nil pra corrigir o problema
	    # corretamente.
	    @failure&.transform_keys(&:to_sym)
	  end

	  def perform
	    begin
	    	@start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
	    	@@config.logger.info("Start perform worker #{self.uuid}")

	    	raise "Can't update worker while it's performing" unless update(status: :processing)
	    	
	    	if element = MethodsChain.run_methods_chain(class_instance, methods_chain)
	    		@@config.logger.info("successful workflow perform worker #{self.uuid}")

	    		klass_after = success[:class_instance] == 'self' ? element : success[:class_instance]
	    		methods_after = success[:methods_chain]

	    		result = MethodsChain.run_methods_chain(klass_after, methods_after)

	    		@end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
	        
	        raise "Can't update worker while it's performing" unless update(status: :done)
	        @@config.logger.info("Done perform worker #{self.uuid}")
	        result
	      else
	      	@@config.logger.error("failure workflow perform worker #{self.uuid}")
	        klass_reject_after = failure[:class_instance] == 'self' ? element : failure[:class_instance]
	        methods_reject_after = failure[:methods_chain]

	        result = MethodsChain.run_methods_chain(klass_reject_after,methods_reject_after)
          
          @end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

	        raise "Can't update worker while it's performing" unless update(
	        			 status: :unprocessable_entity,
	               errors: formated_erros_to_json(result))

	        @@config.logger.error("Done perform worker #{self.uuid} with fails #{formated_erros_to_json(result)}")
	        result
	      end
	    rescue StandardError => e
        @@config.logger.fatal("Fatal perform worker #{self.uuid} with fails #{formated_erros_to_json(e.message)}")
	    	@end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
	      update(status: :internal_server_error, errors: formated_erros_to_json(e.message))
	      nil
	    end
	  end

	  def formated_erros_to_json(errors)
	    resouce = if errors.respond_to?(:map)
	                errors.map { |title, error| { title: title, detail: error } }
	              else
	                [{ title: errors }]
	              end

	    resouce.map { |error| error.select { |_k, v| v.present? } }
	  end


	  def errors=(value)
	  	@errors = value
	  end

	  private
	  def assign_attributes(attrs)
	  	attrs.each do |attribute,value|
	  		send("#{attribute}=", value)
	  	end
	  end

	  def start_time=(value)
	  	@start_time = value
	  end

	  def end_time=(value)
	  	@end_time = value
	  end
	end
end