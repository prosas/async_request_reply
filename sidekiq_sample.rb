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
	
Sidekiq.configure_client do |config|
	config.redis = { url: AsyncRequestReply::Config.instance.redis_url_conection }
end

Sidekiq.configure_server do |config|
	config.redis = { url: AsyncRequestReply::Config.instance.redis_url_conection }
end