module Foobara
  module CommandConnectors
    class Http < Foobara::CommandConnector
      module Commands
        class Describe < Foobara::CommandConnector::Commands::Describe
          inputs do
            manifestable :duck
            request :duck
            detached :boolean, default: true
          end

          def stamp_request_metadata
            manifest[:metadata] = super.merge(url: request.url)
          end

          def in_detached_context(&)
            Thread.foobara_with_var("foobara_manifest_context", detached: true, &)
          end

          def build_manifest
            if detached_context?
              in_detached_context do
                super
              end
            else
              super
            end
          end

          def detached_context?
            detached
          end
        end
      end
    end
  end
end
