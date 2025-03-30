module Foobara
  module CommandConnectors
    class Http < CommandConnector
      class SetInputFromCookie < RequestMutator
        class << self
          attr_accessor :attribute_name, :cookie_name

          def for(attribute_name, cookie_name = attribute_name)
            subclass = Class.new(self)

            subclass.attribute_name = attribute_name
            subclass.cookie_name = cookie_name

            subclass
          end
        end

        attr_writer :attribute_name, :cookie_name

        def inputs_type_from(inputs_type)
          new_declaration = TypeDeclarations::Attributes.reject(inputs_type.declaration_data, attribute_name)
          Domain.current.foobara_type_from_declaration(new_declaration)
        end

        def mutate(request)
          cookie_value = request.cookies[cookie_name]
          request.inputs[attribute_name] = cookie_value
        end

        def attribute_name
          @attribute_name ||= self.class.attribute_name
        end

        def cookie_name
          @cookie_name ||= self.class.cookie_name
        end
      end
    end
  end
end
