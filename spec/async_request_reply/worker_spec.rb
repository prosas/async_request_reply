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

		it 'find' do
			AsyncRequestReply::Worker.find(@async_request.id)
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
				AsyncRequestReply::Config.configure.add_message_pack_factory do |factory|
					factory[:first_byte] = 0x0A
					factory[:klass] = File
					factory[:packer] = lambda { |instance, packer|
						packer.write_string(instance.path)
						encoded_file = File.read(instance.path)
		      	packer.write_string(encoded_file)
		      }
					factory[:unpacker] = lambda { |unpacker|
						file_name = unpacker.read
						bytes_temp_file = unpacker.read
						file = File.new
						file.binmode
						file.write(bytes_temp_file)
						file.close
						file
		      }
		      factory
				end
				file = File.new("./file.txt", "w")
				@async_request.class_instance = file
				_(@async_request.perform).must_equal file
			end
		end
	end
end