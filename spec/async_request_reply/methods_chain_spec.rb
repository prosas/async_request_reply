require "minitest/autorun"
require 'async_request_reply'

describe ::AsyncRequestReply::MethodsChain do

	describe '#run_methods_chain' do
		before do
			@methods_chain = ::AsyncRequestReply::MethodsChain
		end

		it { _(@methods_chain.run_methods_chain(1, [[:+, 1], [:*, 2]])).must_equal 4 }
		it 'run with a proc' do
			a = [1,2,3]
		 _(@methods_chain.run_methods_chain(a, [[:map, Proc.new{|n| n+1}],[:join]])).must_equal "234"
		end
		it 'run with two arguments' do
			_(@methods_chain.run_methods_chain(Math, [[:hypot, [3,4]]])).must_equal 5.0
		end

		it 'run with a String' do
			_(@methods_chain.run_methods_chain(String, [[:new,"a"],[:*,2]])).must_equal "aa"
		end

		it 'run with two arguments and keyworlds arguments' do
			Person = Struct.new(:name, :age, keyword_init: true)

			_(@methods_chain.run_methods_chain(Person, [[:new, [name: "June", age: 33]], [:name]])).must_equal "June"
		end
	end
end