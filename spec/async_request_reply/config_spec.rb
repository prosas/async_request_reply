require "minitest/autorun"
require 'async_request_reply'
describe ::AsyncRequestReply do

	describe 'When init with default configs' do
		before do
			@config = ::AsyncRequestReply::Config.instance
		end

		it "Should init with defaults values" do
			_(@config.config.repository_adapter).must_equal :redis
			_(@config.config.redis_url_conection).must_equal 'redis://localhost:6379'
			if RUBY_VERSION.start_with?('3.') 
				_(@config.config.async_engine).must_equal :async
			else
				_(@config.config.async_engine).must_equal :sidekiq
			end
		end
	end
end