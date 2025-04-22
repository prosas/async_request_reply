# frozen_string_literal: true

module AsyncRequestReply
  # A module providing functionality for chaining method calls on a constant.
  # This class provides a method to execute a series of method calls in sequence on a given constant.
  #
  # == Example:
  #  AsyncRequestReply::MethodsChain.run_methods_chain(1, [[:+, 1], [:*, 2]]) 
  #  # => 4
  #
  # The methods in `attrs_methods` will be called in the order they are provided.
  # If a method requires arguments, the arguments will be passed, otherwise the method will be called without arguments.
  #
  class MethodsChain
    class << self
      # Executes a chain of method calls on a given constant.
      #
      # This method allows chaining of method calls on a constant, where each method can optionally receive parameters.
      # 
      # The constant is first constantized (if it is a string, it will be converted to a constant), and then methods
      # from the `attrs_methods` array are invoked on it in order.
      #
      # @param constant [Object] The constant (or any object) on which methods will be called.
      # @param attrs_methods [Array<Array<Symbol, Object>>] An array of method names and corresponding arguments.
      #   Each element should be a 2-element array where the first element is the method name (as a symbol),
      #   and the second element is the argument to pass to that method. If the method does not require arguments,
      #   the second element can be omitted.
      # 
      # @return [Object] The result of the last method call in the chain.
      #
      # @example
      #   AsyncRequestReply::MethodsChain.run_methods_chain(1, [[:+, 1], [:*, 2]]) 
      #   # => 4
      #
      # @example
      #   AsyncRequestReply::MethodsChain.run_methods_chain("Math::PI", [[:*, 2], [:+, 1]])
      #   # => 7.141592653589793
      def run_methods_chain(constant, attrs_methods = [])
        # The constant is either a string that needs to be constantized or an already defined constant.
        attrs_methods.inject(constant.is_a?(String) ? constant.constantize : constant) do |constantized, method|

          if method[1]
            args = [method[1]].flatten.select{|arg| !arg.is_a?(Hash)}
            kwargs = ([method[1]].flatten.find{|arg| arg.is_a?(Hash)} || {}).symbolize_keys

            # If the argument is a Proc, pass it as a block to the method call.
            next constantized.send(method[0], &args[0]) if args.size == 1 && args[0].is_a?(Proc)

            constantized.send(method[0], *args, **kwargs)

          else
            # If no argument is provided, call the method without parameters.
            constantized.send(method[0])
          end
        end
      end
    end
  end
end
