module Foobara
  module CommandConnectors
    class Http < CommandConnector
      # TODO: what does this have to do with HTTP? Shouldn't this be a generic mutator for all connectors?
      class DefaultInputsRequestMutator < RequestMutator
        class << self
          attr_accessor :defaults

          def for(defaults)
            subclass = Class.new(self)
            subclass.defaults = defaults
            subclass
          end
        end

        def inputs_type_from(inputs_type)
          declaration_data = inputs_type.declaration_data
          existing_defaults ||= declaration_data[:defaults] || {}
          declaration_data = declaration_data.merge(defaults: existing_defaults.merge(defaults))

          if declaration_data.key?(:required)
            declaration_data[:required] = declaration_data[:required] - defaults.keys
          end

          Domain.current.foobara_type_from_declaration(declaration_data)
        end

        def applicable?(_request)
          true
        end

        def mutate(request)
          defaults.each_pair do |key, value|
            unless request.inputs.key?(key)
              request.inputs[key] = if value.is_a?(Proc)
                                      request.instance_exec(&value)
                                    else
                                      value
                                    end
            end
          end
        end

        def defaults = @defaults ||= self.class.defaults
      end
    end
  end
end
