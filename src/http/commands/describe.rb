module Foobara
  module CommandConnectors
    class Http < Foobara::CommandConnector
      module Commands
        class Describe < Foobara::CommandConnector::Commands::Describe
          def stamp_request_metadata
            manifest[:metadata] = super.merge(url: request.url)
          end

          def build_manifest
            Thread.foobara_with_var("foobara_manifest_context", detached: true) do
              super
            end
          end
        end
      end
    end
  end
end
