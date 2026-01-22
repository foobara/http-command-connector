module Foobara
  module CommandConnectors
    class Http < CommandConnector
      module Desugarizers
        class SetInputToProcResult < Desugarizer
          def applicable?(args_and_opts)
            _args, opts = args_and_opts

            return false unless opts.key?(:request_mutators)

            mutators = opts[:request_mutators]
            mutators = Util.array(mutators)

            mutators.any? do |mutator|
              mutator.is_a?(::Hash) && mutator.key?(:set)
            end
          end

          def desugarize(args_and_opts)
            args, opts = args_and_opts

            mutators = opts[:request_mutators]
            resulting_mutators = []

            Util.array(mutators).map do |mutator|
              if mutator.is_a?(::Hash) && mutator.key?(:set)
                if mutator.size > 1
                  # TODO: add test for this
                  # :nocov:
                  resulting_mutators << mutator.except(:set)
                  # :nocov:
                end

                mutator[:set].each_pair do |input_name, proc|
                  resulting_mutators << Http::SetInputToProcResult.for(input_name, &proc)
                end
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
