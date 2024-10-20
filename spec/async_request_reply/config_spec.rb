require "minitest/autorun"
require 'async_request_reply'

describe ::AsyncRequestReply::Config do
	describe 'When set configs' do
		before do
			@config = ::AsyncRequestReply.config do |conf|
				conf.async_engine = :sidekiq
			end
		end
		it 'should set AsyncRequestReply::WorkersEngine::Sidekiq when set :sidekiq' do

			_(@config.configured.async_engine).must_equal AsyncRequestReply::WorkersEngine::Sidekiq
		end

		it 'should never overwrite configs' do
			::AsyncRequestReply.config
			_(@config.configured.async_engine).must_equal AsyncRequestReply::WorkersEngine::Sidekiq
		end
	end
end