require "minitest/autorun"
require 'async_request_reply'
describe ::AsyncRequestReply do

	describe 'When init with default configs' do
		before do
			@config = ::AsyncRequestReply.config
		end

		it "Should init with redis as a repository" do
			_(@config.configured.repository_adapter).must_equal AsyncRequestReply::RepositoryAdapters::RedisRepositoryAdapter
			_(@config.configured.redis_url_conection).must_equal 'redis://localhost:6379'
		end

		it "Should init with AsyncRequestReply::WorkersEngine::Async as a async_engine" do
			_(@config.configured.async_engine).must_equal AsyncRequestReply::WorkersEngine::Async
		end
	end
end