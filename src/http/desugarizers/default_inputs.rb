module Foobara
  module CommandConnectors
    class Http < CommandConnector
      module Desugarizers
        class DefaultInputs < Desugarizer
          def applicable?(args_and_opts)
            _args, opts = args_and_opts

            return false unless opts.key?(:request_mutators)

            mutators = opts[:request_mutators]
            mutators = Util.array(mutators)

            mutators.any? do |mutator|
              mutator.is_a?(::Hash) && mutator.key?(:default)
            end
          end

          def desugarize(args_and_opts)
            args, opts = args_and_opts

            mutators = opts[:request_mutators]
            resulting_mutators = []

            Util.array(mutators).map do |mutator|
              if mutator.is_a?(::Hash) && mutator.key?(:default)
                if mutator.size > 1
                  # TODO: add test for this
                  # :nocov:
                  resulting_mutators << mutator.except(:default)
                  # :nocov:
                end

                resulting_mutators << Http::DefaultInputsRequestMutator.for(mutator[:default])
              else
                # TODO: add a test for this
                # :nocov:
                resulting_mutators << mutator
                # :nocov:
              end
            end

            [args, opts.merge(request_mutators: resulting_mutators)]
          end
        end
      end
    end
  end
end
