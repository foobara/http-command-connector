module Foobara
  module CommandConnectors
    class Http < CommandConnector
      # TODO: We don't really want to mutate the request. We just need access to the authenticated user.
      # consider changing inputs transformer to have access to the command/request somehow
      # TODO: what does this have to do with HTTP? Shouldn't this be a generic mutator for all connectors?
      class SetInputToProcResult < RequestMutator
        class << self
          attr_accessor :attribute_name, :input_value_proc

          def for(attribute_name, &input_value_proc)
            subclass = Class.new(self)

            subclass.attribute_name = attribute_name
            subclass.input_value_proc = input_value_proc

            subclass
          end
        end

        attr_writer :attribute_name, :input_value_proc

        def inputs_type_from(inputs_type)
          new_declaration = TypeDeclarations::Attributes.reject(inputs_type.declaration_data, attribute_name)
          Domain.current.foobara_type_from_declaration(new_declaration)
        end

        def applicable?(_request)
          true
        end

        def mutate(request)
          request.inputs[attribute_name] = request.instance_exec(&input_value_proc)
        end

        def attribute_name
          @attribute_name ||= self.class.attribute_name
        end

        def input_value_proc
          @input_value_proc ||= self.class.input_value_proc
        end
      end
    end
  end
end
