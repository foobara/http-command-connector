module Foobara
  module CommandConnectors
    class Http < CommandConnector
      def context_to_request!(context)
        action = context.action
        full_command_name = context.full_command_name
        inputs = nil

        registry_entry = command_registry[full_command_name]

        case action
        when "run"
          unless registry_entry
            # :nocov:
            raise NoCommandFoundError,
                  "Could not find command registered for #{full_command_name}"
            # :nocov:
          end

          inputs = context.inputs
        when "describe"
          command_class = Foobara::CommandConnectors::Commands::DescribeCommand
          full_command_name = command_class.full_command_name

          inputs = { runnable: registry_entry }
          registry_entry = command_registry[full_command_name] || build_registry_entry(command_class)
        when "ping"
          command_class = Foobara::CommandConnectors::Commands::Ping
          full_command_name = command_class.full_command_name

          registry_entry = command_registry[full_command_name] || build_registry_entry(command_class)
        else
          # :nocov:
          raise InvalidContextError, "Not sure what to do with #{action}"
          # :nocov:
        end

        self.class::Request.new(registry_entry, inputs, context)
      end
    end
  end
end
