require "minitest/autorun"
require 'async_request_reply'
require 'byebug'

describe ::AsyncRequestReply::Worker do
	describe 'when perform with all workflow defined' do
		before do
			@async_request = ::AsyncRequestReply::Worker.new({
				class_instance: 1, methods_chain: [[:+, 1], [:*, 2]],
				success: {
					class_instance: "self",
					methods_chain: [[:+, 1]]
				},
				failure: {
					class_instance: "self",
					methods_chain: [[:*, 3]]
				},
				redirect_url: "teste"
			})
			
			@async_request.save
		end

		it 'perform' do
			_(@async_request.perform).must_equal 5
			_(::AsyncRequestReply::Worker.find(@async_request.uuid).status).must_equal "done"
		end

		it 'destroy' do
			@async_request.destroy(0)
		end

		it 'perform_async' do
			@async_request.perform_async
		end
	end

	describe 'when perform with some parts of workflow' do
		before do
			@async_request = ::AsyncRequestReply::Worker.new
		end

		it 'should not perform with not have class_instance' do
			assert_nil(@async_request.perform)
		end

		describe 'should perform when have class_instance' do
			it 'with constant 1' do
				@async_request.class_instance = 1
				 _(@async_request.perform).must_equal 1
			end

			it 'with constant File' do
				# TODO: This test fail. Messagepack is not 
				# implemented for File.
				# TODO: Create way for inject Messagepack
				# methods
				# @async_request.class_instance = File
				# _(@async_request.perform).must_equal File
			end
		end
	end
end