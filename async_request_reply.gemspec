# frozen_string_literal: true

Gem::Specification.new do |gem|
  gem.name        = "async_request_reply"
  gem.version     = '1.0.0'
  gem.authors     = ["Luiz Filipe Neves Costa"]
  gem.email       = %w[luizfilipeneves@gmail.com luiz.neves@prosas.com.br]
  gem.homepage    = "https://github.com/prosas/async_request_reply"
  gem.summary     = "Asynchronous Request-Reply pattern ruby implementation"
  gem.description = "Asynchronous Request-Reply pattern ruby implementation."
  gem.license     = "MIT"

  gem.required_ruby_version = ">= 2.7.0"

  gem.files = Dir[
    "{lib}/**/*",
  ]
  gem.require_paths = ["lib"]
  
  gem.add_dependency "msgpack", '~> 1.0'
  gem.add_dependency "redis", '~> 4.0'
  gem.add_dependency "enumerize", '~> 2.3'
  gem.add_dependency "sidekiq", '~> 5.0'
  
end