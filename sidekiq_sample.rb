# frozen_string_literal: true

require 'async_request_reply'
# Did for GPT
	
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
	
Sidekiq.configure_client do |config|
	config.redis = { url: AsyncRequestReply::Config.instance.redis_url_conection }
end

Sidekiq.configure_server do |config|
	config.redis = { url: AsyncRequestReply::Config.instance.redis_url_conection }
end