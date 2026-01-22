require "foobara/all"
require "foobara/command_connectors"

Foobara::Util.require_directory "#{__dir__}/../../src"

module Foobara
  module HttpCommandConnector
    class << self
      def install!
        CommandConnector.add_desugarizer CommandConnectors::Http::Desugarizers::SetInputToProcResult
      end
    end
  end

  project "http_command_connector", project_path: "#{__dir__}/../../"
end
