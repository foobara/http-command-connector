module Foobara
  module CommandConnectors
    class Http < CommandConnector
      class Cookie
        attr_accessor :name, :value, :opts

        ALLOWED_OPTIONS = %i[path httponly secure same_site domain expires max_age].freeze

        def initialize(name, value, **opts)
          invalid_options = opts.keys - ALLOWED_OPTIONS

          unless invalid_options.empty?
            # :nocov:
            raise ArgumentError, "Invalid options #{invalid_options.inspect} expected only #{ALLOWED_OPTIONS.inspect}"
            # :nocov:
          end

          self.name = name
          self.value = value
          self.opts = opts.transform_keys(&:to_sym)
        end

        ALLOWED_OPTIONS.each do |option|
          define_method option do
            opts[option]
          end
        end
      end
    end
  end
end
