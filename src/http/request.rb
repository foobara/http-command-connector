require "uri"

module Foobara
  module CommandConnectors
    class Http < CommandConnector
      class Request < CommandConnector::Request
        attr_accessor :path,
                      :method,
                      :headers,
                      :query_string,
                      :body,
                      :scheme,
                      :host,
                      :port,
                      :cookies,
                      :prefix,
                      :remote_ip,
                      :response_headers

        def initialize(
          path:,
          method: nil,
          headers: {},
          query_string: "",
          body: "",
          scheme: nil,
          host: nil,
          port: nil,
          cookies: nil,
          remote_ip: nil,
          prefix: nil
        )
          self.path = path
          self.method = method
          self.headers = headers
          self.query_string = query_string
          self.body = body
          self.scheme = scheme
          self.host = host
          self.port = port
          self.cookies = cookies
          self.remote_ip = remote_ip
          self.prefix = prefix

          super()
        end

        def url
          URI::Generic.build(
            scheme:,
            host:,
            port:,
            path:,
            query: query_string.nil? || query_string.empty? ? nil : query_string
          ).to_s
        end

        def inputs
          @inputs ||= parsed_body.merge(parsed_query_string)
        end

        def full_command_name
          unless defined?(@full_command_name)
            set_action_and_command_name
          end

          @full_command_name
        end

        def parsed_body
          body.empty? ? {} : JSON.parse(body)
        end

        def parsed_query_string
          if query_string.nil? || query_string.empty?
            {}
          else
            # TODO: override this in rack connector to use better rack utils
            CGI.parse(query_string).transform_values!(&:first)
          end
        end

        def action
          unless defined?(@action)
            set_action_and_command_name
          end

          @action
        end

        def argument
          prefixless_path.split("/")[2]
        end

        def set_action_and_command_name
          @action, *full_command_name = prefixless_path[1..].split("/")

          @full_command_name = full_command_name.join("::").gsub("/", "::")
        end

        def prefixless_path
          return @prefixless_path if defined?(@prefixless_path)

          prefix = self.prefix

          @prefixless_path = if prefix
                               path.gsub(/^#{prefix}\//, "/")
                             else
                               path
                             end
        end

        def set_response_header(name, value)
          name = name.to_s
          name = name.downcase

          self.response_headers ||= {}
          self.response_headers = response_headers.merge(name => value)
        end
      end
    end
  end
end
