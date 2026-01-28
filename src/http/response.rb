module Foobara
  module CommandConnectors
    class Http < CommandConnector
      class Response < CommandConnector::Response
        attr_accessor :headers
        attr_writer :cookies

        def initialize(headers: nil, cookies: nil, **)
          self.headers = headers
          self.cookies = cookies

          super(**)
        end

        def cookies
          @cookies ||= []
        end

        def add_cookie(cookie_name, cookie_value, **cookie_opts)
          cookies << Cookie.new(cookie_name, cookie_value, **cookie_opts)
        end

        def add_header(header_name, header_value)
          self.headers ||= {}
          headers[header_name] = header_value
        end
      end
    end
  end
end
