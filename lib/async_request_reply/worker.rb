# frozen_string_literal: true
require_relative 'config'
require_relative 'methods_chain'

# TODO[DANGER]: Mockeypath na classe ActionDispatch::Http::UploadedFile
# para tornar possível implementação do método to_msgpack para params
# vindo da controller. Em implementações futuras fazer o hacking direto no método to_msgpack
module ActionDispatch
  module Http
    class UploadedFile
      def as_json
        self
      end
    end
  end
end

module AsyncRequestReply
	class Worker
		# TODO-2023-10-22: Adicinar mais logs a classe.
	  # include ActiveModel::API
	  include ActiveModel::Model
	  include ActiveModel::Validations
	  include ActiveModel::Naming
	  include ActiveModel::Serializers::JSON

  	@@config = AsyncRequestReply::Config.instance

	  STATUS = %i[waiting processing done unprocessable_entity internal_server_error]
	  LIVE_TIMEOUT = 1.hours.to_i # TODO-2023-10-22: Isso limita o processamento de máximo 1 hora.

	  attr_accessor :status, :uuid, :status_url, :redirect_url,
	                :class_instance, :methods_chain, :success,
	                :redirect_url, :failure, :_ttl
	  attr_reader :new_record

	  validates_presence_of :class_instance


	  def initialize(attrs = {})
	    attrs.symbolize_keys!
	    @uuid = new_record?(attrs[:uuid]) ? "async_request:#{SecureRandom.uuid}" : attrs[:uuid]

	    # INFO: Remover do repositório depois que async_request for processado
	    # TODO-2023-10-22: Entender a relação entre número de objetos criados e
	    # consulmo de mémoria no host onde está o redis. Definir uma estrátegia
	    # que limite o tamanho máximo de uma instância da classe e controle do ciclo
	    # de vida de cada instancia no banco pra ofecer melhor controle pra cada caso
	    # de uso.
	    destroy(30.seconds.to_i) if !new_record?(attrs[:uuid]) && attrs[:status].to_sym == :done
	    
	    super(default_attributes.merge(attrs))
	  end

	  def attributes
	    { 'uuid' => uuid,
	      'status' => status,
	      'success' => success,
	      'failure' => failure,
	      'methods_chain' => methods_chain,
	      'class_instance' => class_instance,
	      'redirect_url' => redirect_url
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
	    return nil unless resource.present?

	    new(resource)
	  end

	  def self._find(p_uuid)
	    resource = @@config.repository_adapter.get(p_uuid)
	    return nil unless resource

	    unpack(@@config.repository_adapter.get(p_uuid))
	  end


	  def update(attrs)
	    assign_attributes(attrs)
	    save
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
	    @@config.repository_adapter.setex(uuid, (_ttl || LIVE_TIMEOUT), to_msgpack)
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
	    factory.register_type(
	      0x09,
	      ActionDispatch::Http::UploadedFile,
	      packer: lambda { |upload, packer|
	        packer.write_string(upload.original_filename)
	        encoded_file = Base64.encode64(upload.tempfile.open.read)
	        packer.write_string(encoded_file)
	        packer.write_string(upload.content_type)
	        packer.write_string(upload.headers)
	      },
	      unpacker: lambda { |unpacker|
	        file_name = unpacker.read
	        bytes_temp_file = Base64.decode64(unpacker.read)
	        headers = unpacker.read

	        file = Tempfile.new(file_name)
	        file.binmode
	        file.write(bytes_temp_file)
	        file.close

	        content_type = unpacker.read
	        ActionDispatch::Http::UploadedFile.new(tempfile: file, type: content_type, head: headers, filename: file_name)
	      },
	      recursive: true
	    )
	    factory
	  end

	  def success
	    # TODO-2023-10-22: Entender em que momento do ciclo de vida
	    # do objeto que esse atributo é nil pra corrigir o problema
	    # corretamente.
	    @success&.symbolize_keys
	  end

	  def failure
	    # TODO-2023-10-22: Entender em que momento do ciclo de vida
	    # do objeto que esse atributo é nil pra corrigir o problema
	    # corretamente.
	    @failure&.symbolize_keys
	  end

	  def perform
	    return nil unless update(status: :processing)

	    begin
	      element = MethodsChain.run_methods_chain(class_instance, methods_chain)

	      klass_after = success[:class_instance] == 'self' ? element : success[:class_instance]
	      methods_after = success[:methods_chain]
	      if result = MethodsChain.run_methods_chain(klass_after, methods_after)
	        update(
	          status: :done,
	          redirect_url: if redirect_url.is_a?(Hash)
	                          MethodsChain.run_methods_chain(redirect_url[:class_instance],
	                                            redirect_url[:methods_chain])
	                        else
	                          redirect_url
	                        end
	        )
	        result
	      else
	        klass_reject_after = failure[:class_instance] == 'self' ? element : failure[:class_instance]
	        methods_reject_after = failure[:methods_chain]

	        result = MethodsChain.run_methods_chain(klass_reject_after,methods_reject_after)
	        update(status: :unprocessable_entity,
	               errors: formated_erros_to_json(JSON.parse(result)))
	      end
	    rescue StandardError => e
	    	raise e
	      update(status: :internal_server_error, errors: formated_erros_to_json(e))
	    end
	  end

	  # TODO: Remove do worker formatação dos erros.
	  def formated_erros_to_json(errors)
	    errors = errors.as_json
	    resouce = if errors.respond_to?(:map)
	                errors.map { |title, error| { title: title, detail: error } }
	              else
	                [{ title: errors }]
	              end

	    resouce.map { |error| error.select { |_k, v| v.present? } }
	  end	  
	end
end