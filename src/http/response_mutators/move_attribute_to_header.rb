module Foobara
  module CommandConnectors
    class Http < CommandConnector
      class MoveAttributeToHeader < ResponseMutator
        class << self
          attr_accessor :attribute_name, :header_name

          def for(attribute_name, header_name = attribute_name)
            subclass = Class.new(self)

            subclass.attribute_name = attribute_name
            subclass.header_name = header_name

            subclass
          end
        end

        attr_writer :attribute_name, :header_name

        def result_type_from(result_type)
          new_declaration = TypeDeclarations::Attributes.reject(result_type.declaration_data, attribute_name)
          Domain.current.foobara_type_from_declaration(new_declaration)
        end

        def mutate(response)
          if response.command.success?
            header_value = response.body.delete(attribute_name)
            response.add_header(header_name, header_value)
          end
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
