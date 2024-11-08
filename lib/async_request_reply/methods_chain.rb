# frozen_string_literal: true

module AsyncRequestReply
	class MethodsChain
		class << self
			def run_methods_chain(constant, attrs_methods = [])
				# Recebe uma constanta e um array de metodos e paramêtros que serão chamados em sequência
				#
				# Exemplo:
				# >> AsyncRequestReply::MethodsChain.run_methods_chain(1, [[:+, 1], [:*, 2]])
				# => 4
				#
				# Arguments:
				# constant: (Constante)
				# attrs_methods: (Array)

		    attrs_methods.inject(constant) do |constantized, method|
		      if method[1]
		        attrs = method[1]
		        
		        attrs.is_a?(Proc) ? constantized.send(method[0], &attrs) : constantized.send(method[0], *attrs)
		      else
		        constantized.send(method[0])
		      end
		    end
		  end
		end
	end
end