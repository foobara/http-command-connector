module Foobara
  module CommandConnectors
    class Http < CommandConnector
      class MoveAttributeToCookie < ResponseMutator
        class << self
          attr_accessor :attribute_name, :cookie_name, :cookie_opts

          def for(attribute_name, cookie_name = attribute_name, **cookie_opts)
            subclass = Class.new(self)

            subclass.attribute_name = attribute_name
            subclass.cookie_name = cookie_name
            subclass.cookie_opts = cookie_opts

            subclass
          end
        end

        attr_writer :attribute_name, :cookie_name, :cookie_opts

        def result_type_from(result_type)
          new_declaration = TypeDeclarations::Attributes.reject(result_type.declaration_data, attribute_name)

          Domain.current.foobara_type_from_declaration(new_declaration)
        end

        def applicable?(response)
          response.command.success?
        end

        def mutate(response)
          cookie_value = response.body.delete(attribute_name)
          response.add_cookie(cookie_name, cookie_value, cookie_opts)
        end

        def attribute_name
          @attribute_name ||= self.class.attribute_name
        end

        def cookie_name
          @cookie_name ||= self.class.cookie_name
        end

        def cookie_opts
          @cookie_opts ||= self.class.cookie_opts
        end
      end
    end
  end
end
