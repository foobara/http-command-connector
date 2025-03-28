module Foobara
  module CommandConnectors
    class Http < CommandConnector
      module Commands
        class Help < Command
          description "Will extract items from the request to help with"
          inputs request: Http::Request
          result :duck
          possible_error CommandConnector::NotFoundError

          def execute
            load_manifest
            determine_object_to_help_with
            set_manifest_to_help_with

            manifest_to_help_with
          end

          attr_accessor :raw_manifest, :root_manifest, :object_to_help_with, :manifest_to_help_with

          def load_manifest
            self.raw_manifest = command_connector.foobara_manifest
            self.root_manifest = Manifest::RootManifest.new(raw_manifest)
          end

          def determine_object_to_help_with(mode: Namespace::LookupMode::ABSOLUTE)
            arg = request.argument

            if arg
              result = command_connector.command_registry.foobara_lookup(arg, mode:)

              if result
                self.object_to_help_with = result
              else
                # TODO: we should look up from the command connector's namespace instead, right?
                result = GlobalOrganization.foobara_lookup(arg, mode:)

                if result && root_manifest.contains?(result.foobara_manifest_reference,
                                                     result.scoped_category)
                  self.object_to_help_with = result
                elsif mode == Namespace::LookupMode::ABSOLUTE
                  determine_object_to_help_with(mode: Namespace::LookupMode::GENERAL)
                elsif mode == Namespace::LookupMode::GENERAL
                  determine_object_to_help_with(mode: Namespace::LookupMode::RELAXED)
                else
                  # TODO: add an input error instead for missing record to trigger 404
                  add_runtime_error(CommandConnector::NotFoundError.new(arg))
                end
              end
            else
              self.object_to_help_with = root_manifest
            end
          end

          def set_manifest_to_help_with
            self.manifest_to_help_with = if object_to_help_with.is_a?(Manifest::BaseManifest)
                                           object_to_help_with
                                         else
                                           root_manifest.lookup(object_to_help_with.foobara_manifest_reference)
                                         end
          end

          def command_connector
            request.command_connector
          end
        end
      end
    end
  end
end
