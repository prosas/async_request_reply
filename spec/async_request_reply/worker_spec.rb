require 'minitest/autorun'
require 'async_request_reply'
require 'byebug'

describe ::AsyncRequestReply::Worker do
  describe 'when perform with all workflow defined' do
    before do
      @async_request = ::AsyncRequestReply::Worker.new({
                                                         class_instance: 1, methods_chain: [[:+, 1], [:*, 2]],
                                                         success: {
                                                           class_instance: 'self',
                                                           methods_chain: [[:+, 1]]
                                                         },
                                                         failure: {
                                                           class_instance: 'self',
                                                           methods_chain: [[:*, 3]]
                                                         },
                                                         redirect_url: 'teste'
                                                       })

      @async_request.save
    end

    it 'perform' do
      _(AsyncRequestReply::Worker.find(@async_request.id).perform).must_equal 5
      _(AsyncRequestReply::Worker.find(@async_request.id).start_time).wont_be_nil
      _(AsyncRequestReply::Worker.find(@async_request.id).end_time).wont_be_nil
      _(AsyncRequestReply::Worker.find(@async_request.id).elapsed).wont_be_nil
      _(AsyncRequestReply::Worker.find(@async_request.uuid).status).must_equal 'done'
    end

    describe 'failure workflow' do
      describe 'internal_server_error' do
        it '.perform' do
          @async_request.methods_chain = [[:/, 0]]
          @async_request.save
          assert_nil(AsyncRequestReply::Worker.find(@async_request.id).perform)
          _(AsyncRequestReply::Worker.find(@async_request.id).start_time).wont_be_nil
          _(AsyncRequestReply::Worker.find(@async_request.id).end_time).wont_be_nil
          _(AsyncRequestReply::Worker.find(@async_request.id).elapsed).wont_be_nil
          _(AsyncRequestReply::Worker.find(@async_request.uuid).status).must_equal 'internal_server_error'
        end
      end
      describe 'fail' do
        it '.perform' do
          @async_request.methods_chain = [[:==, 2]]
          @async_request.failure = { class_instance: 0, methods_chain: [] }
          @async_request.save
          _(AsyncRequestReply::Worker.find(@async_request.id).perform).must_equal 0
          _(AsyncRequestReply::Worker.find(@async_request.id).start_time).wont_be_nil
          _(AsyncRequestReply::Worker.find(@async_request.id).end_time).wont_be_nil
          _(AsyncRequestReply::Worker.find(@async_request.id).elapsed).wont_be_nil
          _(AsyncRequestReply::Worker.find(@async_request.uuid).status).must_equal 'unprocessable_entity'
        end
      end
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
        AsyncRequestReply.configure do |conf|
          conf.add_message_pack_factory do |factory|
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

              # Criando um Tempfile
              tempfile = Tempfile.new('meu_arquivo_temp')
              tempfile.write('Este é um conteúdo temporário.')
              tempfile.rewind

              # Definindo o caminho para o arquivo permanente
              file_path = file_name

              # Copiando o conteúdo do Tempfile para um arquivo permanente
              File.open(file_path, 'w') do |file|
                file.write(tempfile.read)
              end

              # Fechando e excluindo o Tempfile
              tempfile.close
              tempfile.unlink
              # debugger
              File.open(file_path)
            }
            factory
          end
        end

        file = File.new('./file.txt', 'w')

        @async_request.class_instance = file
        _(@async_request.perform.path).must_equal file.path

        _(File.open(@async_request.perform.path).read).must_equal File.open(file).read
      end
    end
  end
end
