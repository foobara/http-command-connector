require "pathname"

require_relative "presenter/command"
require_relative "presenter/entity"
require_relative "presenter/error"
require_relative "presenter/model"
require_relative "presenter/organization"
require_relative "presenter/domain"
require_relative "presenter/processor"
require_relative "presenter/processor_class"
require_relative "presenter/root"
require_relative "presenter/type"

module Foobara
  module CommandConnectors
    class Http < CommandConnector
      module Commands
        class Help < Command
          class Presenter
            class << self
              def for(manifest)
                case manifest
                when Manifest::RootManifest
                  Presenter::Root
                when Manifest::Command
                  Presenter::Command
                  # TODO: do we need a dedicated presenter for this??
                when Manifest::Entity, Manifest::DetachedEntity
                  Presenter::Entity
                when Manifest::Model
                  Presenter::Model
                when Manifest::Type
                  Presenter::Type
                when Manifest::Error
                  Presenter::Error
                when Manifest::Domain
                  Presenter::Domain
                when Manifest::Organization
                  Presenter::Organization
                when Manifest::Processor
                  Presenter::Processor
                when Manifest::ProcessorClass
                  Presenter::ProcessorClass
                when ErrorCollection
                  Presenter::RequestFailed
                else
                  # :nocov:
                  raise "No presenter found for #{manifest.path}"
                  # :nocov:
                end.new(manifest)
              end

              def template_symbol
                Util.underscore(Util.non_full_name(self))
              end

              def template_path
                template_path = File.join(
                  __dir__,
                  "templates",
                  "#{template_symbol}.html.erb"
                )
                Pathname.new(template_path).cleanpath.to_s
              end
            end

            attr_accessor :manifest

            def initialize(manifest)
              self.manifest = manifest
            end

            def render_html_list(data)
              html = +""

              is_rendered_as_a_collection = rendered_as_collection?(data)

              html << "<ul>" if is_rendered_as_a_collection

              case data
              when ::Hash
                data.each do |key, value|
                  html << render_list_child(value, key)
                end
              when ::Array
                if is_rendered_as_a_collection
                  data.each do |item|
                    html << render_list_child(item)
                  end
                else
                  data = data.map { |item| render_html_list(item) }
                  html << "[#{data.join(", ")}]"
                end
              when Manifest::Attributes
                data.relevant_manifest.each_pair do |key, value|
                  if key.to_s == "type"
                    next
                  end

                  if key.to_s == "element_type_declarations"
                    key = :attributes
                    value = data.attribute_declarations
                  end

                  html << render_list_child(value, key)
                end
              when Manifest::Array
                data.relevant_manifest.each_pair do |key, value|
                  next if key == :element_type_declaration

                  if key.to_s == "type"
                    value = root_manifest.lookup_path(key, value)
                  end
                  html << render_list_child(value, key)
                end

                html << render_html_list({ element_type: data.element_type })
              when Manifest::TypeDeclaration
                manifest = data.relevant_manifest

                if manifest.is_a?(::Symbol)
                  html << foobara_reference_link(data.to_type)
                else
                  data.relevant_manifest.each_pair do |key, value|
                    if key.to_s == "type"
                      value = root_manifest.lookup_path(key, value)
                    end

                    html << render_list_child(value, key)
                  end
                end
              when Manifest::Type, Manifest::Command, Manifest::Error
                html << foobara_reference_link(data)
              when Manifest::PossibleError
                html << render_html_list(data.error)
              else
                html << case data
                        when Numeric, TrueClass, FalseClass, NilClass
                          data.inspect
                        when ::String
                          data
                        when ::Symbol, ::Time
                          data.to_s
                        else
                          # :nocov:
                          raise "Not sure how to render #{data.class}"
                          # :nocov:
                        end
              end

              html << "</ul>" if is_rendered_as_a_collection

              html
            end

            def rendered_as_collection?(data)
              if data.is_a?(::Array)
                data.size > 5 || data.any? { |element| rendered_as_collection?(element) }
              elsif data.is_a?(Manifest::TypeDeclaration)
                !data.relevant_manifest.is_a?(::Symbol)
              else
                [
                  ::Hash,
                  Manifest::Attributes,
                  Manifest::Array
                ].any? { |klass| data.is_a?(klass) }
              end
            end

            def render_list_child(child, name = nil)
              if name
                name = "#{name}:"
              end

              "<li>#{name}\n#{render_html_list(child)}\n</li>"
            end

            def foobara_reference_link(manifest)
              path = "/help/#{manifest.reference}"

              "<a href=\"#{path}\">#{manifest.reference.split("::").last}</a>"
            end

            def root_manifest
              @root_manifest ||= Manifest::RootManifest.new(manifest.root_manifest)
            end

            def template_path
              self.class.template_path
            end

            def method_missing(method_name, *, &)
              if manifest.respond_to?(method_name)
                manifest.send(method_name, *, &)
              else
                # :nocov:
                super
                # :nocov:
              end
            end

            def respond_to_missing?(method_name, include_private = false)
              # :nocov:
              manifest.respond_to?(method_name, include_private)
              # :nocov:
            end
          end
        end
      end
    end
  end
end
