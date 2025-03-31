module Foobara
  module CommandConnectors
    class Http < CommandConnector
      class SetHeader < ResponseMutator
        class << self
          attr_accessor :header_name, :header_value

          def for(header_name, header_value)
            subclass = Class.new(self)

            subclass.header_name = header_name
            subclass.header_value = header_value

            subclass
          end
        end

        attr_writer :header_name, :header_value

        def result_type_from(result_type)
          result_type
        end

        def mutate(response)
          response.add_header(header_name.to_s, header_value)
        end

        def header_name
          @header_name ||= self.class.header_name
        end

        def header_value
          @header_value ||= self.class.header_value
        end
      end
    end
  end
end
