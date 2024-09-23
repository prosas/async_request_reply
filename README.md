# Async Request Reply
Implementation for Asynchronous Request-Reply pattern.

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
ActiveAsyncRequestReply.config do |conf|
  conf.redis_url_conection = 'redis://localhost:6379'
  conf.async_engine = :sidekiq
end
```
# Methods Chain
It’s an interface that receives a class or instance and an array of methods and parameters to run in sequence. For example:
```ruby
@methods_chain = ::ActiveAsyncRequestReply::MethodsChain
@methods_chain.run_methods_chain(1, [[:+, 1], [:*, 2]])
# >> 4
```
It`s same that call:

```ruby
1.send(:+,1).send(:*,2)
```
This way you can easy save this instruction for run later. 

# Basic usage
With ::ActiveAsyncRequestReply::Worker you can save _methods chain_ instructions for run later.
```ruby
@async_request = ::ActiveAsyncRequestReply::Worker.new({class_instance: 1, methods_chain: [[:+, 1], [:*, 2]]})
@async_request.save
::ActiveAsyncRequestReply::Worker.find(@async_request.id).perform
```
Or you can call _perform_async_. ::ActiveAsyncRequestReply::Worker never save the result of _methods chain_.
```ruby
class Project
	def self.very_expensive_task
		#...
	end
end
@async_request = ::ActiveAsyncRequestReply::Worker.new({class_instance: Project, methods_chain: [[:very_expensive_task]]})
@async_request.perform_async
```
You can define a methods chain for success and failure.

# Define your own repository
_TODO_

# Define your own async engine

# Test

```
rake test
```