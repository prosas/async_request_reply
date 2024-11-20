require "minitest/autorun"
require 'async_request_reply'
require "byebug"
describe ::AsyncRequestReply do

	describe 'When init with default configs' do
		before do
			class Fibonacci end
			@config = ::AsyncRequestReply::Config.instance
		end

		it "Should init with defaults values" do
			_(@config.config.repository_adapter).must_equal :redis
			_(@config.config.redis_url_conection).must_equal 'redis://localhost:6379'
			_(@config.config.async_engine).must_equal :sidekiq
		end

		it ".add_message_pack_factory" do
			@config.add_message_pack_factory do |factory|
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

			factory = @config.message_packer_factories.find{|factory| factory[:klass] == Fibonacci}
			_(factory[:klass]).must_equal Fibonacci
			_(factory[:first_byte]).must_equal 0x09
		end
	end
end