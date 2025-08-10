# Async Request Reply

An implementation of the **Asynchronous Request-Reply** pattern, providing a unified interface to make your code asynchronous with ease.

## Overview

For a general understanding of the async request-reply pattern, check out this [Microsoft guide](https://learn.microsoft.com/en-us/azure/architecture/patterns/async-request-reply).

## Installation

Install the gem:

```sh
gem install async_request_reply
```

## Method Chain

This interface allows you to chain and execute a sequence of method calls on a class or instance:

```ruby
@methods_chain = ::AsyncRequestReply::MethodsChain
@methods_chain.run_methods_chain(1, [[:+, 1], [:*, 2]])
# => 4
```

Equivalent to:

```ruby
1.send(:+, 1).send(:*, 2)
```

This is useful when you want to store and replay a sequence of operations later.

## Instruction Storage

Internally, **AsyncRequestReply** uses [MessagePack](https://msgpack.org/) to serialize instructions. It first tries to serialize using JSON, and falls back to MessagePack for complex objects (like a `File` instance).

## Basic Usage

With `::AsyncRequestReply::Worker`, you can store a method chain for later execution:

```ruby
@async_request = ::AsyncRequestReply::Worker.new({
  class_instance: 1,
  methods_chain: [[:+, 1], [:*, 2]]
})
@async_request.save
::AsyncRequestReply::Worker.find(@async_request.id).perform
```

Or run it asynchronously:

```ruby
class Project
  def self.very_expensive_task
    # ...
  end
end

@async_request = ::AsyncRequestReply::Worker.new({
  class_instance: 'Project',
  methods_chain: [[:very_expensive_task]]
})
@async_request.perform_async
```

> **Note**: `AsyncRequestReply::Worker` **does not** store the result of the method chain.

You can also define separate method chains for success and failure:
```ruby
@async_request = ::AsyncRequestReply::Worker.new({
  class_instance: 'Project',
  methods_chain: [[:very_expensive_task]],
  success: {
    class_instance: 'self',
    methods_chain: [[:notify_success]]
  },
  failure: {
    class_instance: 'self',
    methods_chain: [[:notify_failure]]
  }
})
@async_request.perform_async
```

## Custom MessagePack Factories

For complex objects, you can define custom serialization strategies:

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
    file = File.new(file_name, 'w')
    file.binmode
    file.write(bytes_temp_file)
    file.close
    file
  }
end

file = File.new("./file.txt", "w")
@async_request = ::AsyncRequestReply::Worker.new
@async_request.class_instance = file
@async_request.perform_async
```
## Configuration Redis & Sidekiq

By default, AsyncRequestReply is implemented a simple storage instruction and async engine. For production scenario, you can configure Redis and Sidekiq. Here's how to set up the configuration:

```ruby
AsyncRequestReply.config do |conf|
  conf.redis_url_conection = 'redis://localhost:6379'
  conf.async_engine = :sidekiq
end
```

## Define Your Own Repository

You can create custom repository adapters by implementing the `AbstractRepositoryAdapter` class. This allows you to use different storage backends while maintaining the same interface.

### Repository Adapter Interface

Your custom repository adapter must implement these three methods:

- `get(uuid)` - Retrieves data by UUID, returns `nil` if not found
- `del(uuid)` - Deletes data by UUID
- `setex(uuid, ttl, payload)` - Stores data with optional TTL, returns the stored data

### Example: File-based Repository

Here's an example of a file-based repository adapter (similar to the built-in `IORepositoryAdapter`):

```ruby
require_relative 'abstract_repository_adapter'
require 'tmpdir'

module AsyncRequestReply
  module RepositoryAdapters
    class FileRepositoryAdapter < AbstractRepositoryAdapter
      @@prefix = ".my_async_storage".freeze
      
      class << self
        def get(uuid)
          begin
            IO.binread("#{@@prefix}/#{uuid}")
          rescue StandardError => e
            return nil if e.is_a?(Errno::ENOENT)
            raise e
          end
        end

        def del(uuid)
          File.delete("#{@@prefix}/#{uuid}")
        end

        def setex(uuid, ttl = nil, payload)
          Dir.mkdir(@@prefix) unless Dir.exist?(@@prefix)
          IO.binwrite("#{@@prefix}/#{uuid}", payload)
          self.get(uuid)
        end
      end
    end
  end
end
```

### Using Your Custom Repository

To use your custom repository adapter, configure it in your application:

```ruby
AsyncRequestReply.config do |conf|
  conf.repository_adapter = FileRepositoryAdapter
end
```

### Key Considerations

- **Error Handling**: Handle file system errors gracefully, especially `ENOENT` (file not found)
- **Directory Creation**: Ensure the storage directory exists before writing files
- **Binary Data**: Use `IO.binread` and `IO.binwrite` for binary data compatibility
- **TTL Support**: While the interface includes TTL, file-based storage doesn't automatically expire files
- **Thread Safety**: Consider thread safety if your adapter will be used in multi-threaded environments

## Create a Custom Async Engine

You can provide your own async engine by implementing a class that responds to `perform_async`, receiving the ID of the `AsyncRequestReply::Worker` instance:

```ruby
class MyAsync
  def self.perform_async(async_request_id)
    worker = AsyncRequestReply::Worker.find(async_request_id)
    # Perform async task...
  end
end

# Configurations
AsyncRequestReply.config do |conf|
  conf.async_engine = MyAsync
end
```

## Batch Execution

You can execute multiple workers in a batch:

```ruby
worker1 = AsyncRequestReply::Worker.new({
  class_instance: Fibonacci.new,
  methods_chain: [[:sequence, 35]]
})

worker2 = AsyncRequestReply::Worker.new({
  class_instance: Fibonacci.new,
  methods_chain: [[:sequence, 35]]
})

batch = AsyncRequestReply::WorkerInBatch.new
batch.workers = [worker1, worker2]
batch.save

batch = AsyncRequestReply::WorkerInBatch.find(batch.id)
batch.perform
```

## Running Tests

Run tests using:

```sh
rake test
```