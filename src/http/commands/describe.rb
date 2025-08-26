module Foobara
  module CommandConnectors
    class Http < Foobara::CommandConnector
      module Commands
        class Describe < Foobara::CommandConnector::Commands::Describe
          inputs do
            manifestable :duck
            request :duck
            detached :boolean, default: false
            include_processors :boolean, default: false
          end

          def stamp_request_metadata
            manifest[:metadata] = super.merge(url: request.url)
          end

          def build_manifest
            TypeDeclarations.with_manifest_context(detached:, include_processors:) do
              super
            end
          end
        end
      end
    end
  end
end
