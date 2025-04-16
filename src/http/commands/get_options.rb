module Foobara
  module CommandConnectors
    class Http < CommandConnector
      module Commands
        # TODO: this is a bit of a hack, just a total no-op... shouldn't really need this command at all ideally
        class GetOptions < Foobara::Command
          inputs do
            request :duck, :required
          end
          result :string

          def execute
            initialize_response_headers

            set_allow_methods
            set_allow_headers
            set_access_control_max_age

            # TODO: what's with this empty string?
            ""
          end

          def initialize_response_headers
            request.response_headers ||= {}
          end

          def set_allow_methods
            allow_methods = ENV.fetch("FOOBARA_HTTP_RESPONSE_HEADER_ACCESS_CONTROL_ALLOW_METHODS", nil)
            if allow_methods
              request.response_headers["access-control-allow-methods"] = allow_methods
            end
          end

          def set_allow_headers
            allow_headers = ENV.fetch("FOOBARA_HTTP_RESPONSE_HEADER_ACCESS_CONTROL_ALLOW_HEADERS", nil)
            if allow_headers
              if allow_headers == "*"
                allow_headers = request.headers["access-control-request-headers"]
              end
              request.response_headers["access-control-allow-headers"] = allow_headers
            end
          end

          def set_access_control_max_age
            access_control_max_age = ENV.fetch("FOOBARA_HTTP_RESPONSE_HEADER_ACCESS_CONTROL_MAX_AGE", nil)
            if access_control_max_age
              request.response_headers["access-control-max-age"] = access_control_max_age
            end
          end
        end
      end
    end
  end
end
