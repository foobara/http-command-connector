module Foobara
  module CommandConnectors
    class Http < CommandConnector
      class SetInputFromHeader < RequestMutator
        class << self
          attr_accessor :attribute_name, :header_name

          def for(attribute_name, header_name = attribute_name)
            subclass = Class.new(self)

            header_name = header_name.to_s if header_name.is_a?(::Symbol)

            subclass.attribute_name = attribute_name
            subclass.header_name = header_name

            subclass
          end
        end

        attr_writer :attribute_name, :header_name

        def inputs_type_from(inputs_type)
          new_declaration = TypeDeclarations::Attributes.reject(inputs_type.declaration_data, attribute_name)
          Domain.current.foobara_type_from_declaration(new_declaration)
        end

        def mutate(request)
          header_value = request.headers[header_name]
          request.inputs[attribute_name] = header_value
        end

        def attribute_name
          @attribute_name ||= self.class.attribute_name
        end

        def header_name
          @header_name ||= self.class.header_name
        end
      end
    end
  end
end
