# Async Request Reply
Implementation of the Asynchronous Request-Reply pattern and a unified interface to make your code asynchronous.

# Async Request Reply Workflow
You can see [here](https://learn.microsoft.com/en-us/azure/architecture/patterns/async-request-reply).

# Installation
Install gem:
```sh
 gem install async_request_reply
```
# Configuration
By default, AsyncRequestReply depends on Redis and Sidekiq. Here's how you can define the basic configuration.
```ruby
AsyncRequestReply.config do |conf|
  conf.redis_url_conection = 'redis://localhost:6379'
  conf.async_engine = :sidekiq
end
```
# Methods Chain
It’s an interface that receives a class or instance and an array of methods and parameters to run in sequence. For example:
```ruby
@methods_chain = ::AsyncRequestReply::MethodsChain
@methods_chain.run_methods_chain(1, [[:+, 1], [:*, 2]])
# >> 4
```
It`s same that call:

```ruby
1.send(:+,1).send(:*,2)
```
This way you can easy save this instruction for run later.

# How instruction are saves
_TODO_

# Basic usage
With ::AsyncRequestReply::Worker you can save _methods chain_ instructions for run later.
```ruby
@async_request = ::AsyncRequestReply::Worker.new({class_instance: 1, methods_chain: [[:+, 1], [:*, 2]]})
@async_request.save
::AsyncRequestReply::Worker.find(@async_request.id).perform
```
Or you can call _perform_async_.
AsyncRequestReply::Worker never save the result of _methods chain_.

```ruby
class Project
	def self.very_expensive_task
		#...
	end
end
@async_request = ::AsyncRequestReply::Worker.new({class_instance: 'Project', methods_chain: [[:very_expensive_task]]})
@async_request.perform_async
```
You can define a methods chain for success and failure.

# Defining message packer factories
```ruby
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
@async_request = ::AsyncRequestReply::Worker.new
@async_request.class_instance = file
@async_request.perform_async
```

# Define your own repository
_TODO_

# Define your own async engine
_TODO_

# Worker In Batch
```ruby
worker1 = AsyncRequestReply::Worker.new({ class_instance: Fibonacci.new, methods_chain: [[:sequence, 35]]})
worker2 = AsyncRequestReply::Worker.new({ class_instance: Fibonacci.new, methods_chain: [[:sequence, 35]]})

batch = AsyncRequestReply::WorkerInBatch.new
batch.workers = [worker1, worker2]
batch.save
batch = AsyncRequestReply::WorkerInBatch.find(batch.id)
batch.perform
```

# Test

```
rake test
```
