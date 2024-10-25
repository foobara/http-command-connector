require "foobara/all"
require "foobara/command_connectors"

module Foobara
  module CommandConnectorsHttp
  end

  Monorepo.project :command_connectors_http
end

Foobara::Util.require_directory "#{__dir__}/../../src"
