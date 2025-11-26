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
              html = ""
              case data
              when ::Hash
                # html << "<ul>" unless skip_wrapper
                html << "<ul>"
                data.each do |key, value|
                  html << "<li>#{key} -----HASH-----"
                  # html << "<ul>"
                  html << render_html_list(value)
                  # html << "</ul>"
                  html << "</li>"
                end
                html << "</ul>"
                # html << "</ul>" unless skip_wrapper
              when ::Array
                # html << "<ul>" unless skip_wrapper
                # html << "<ul>"
                data.each do |item|
                  # html << "----ARRAY_ITEM-----"
                  html << render_html_list(item)
                end
                # html << "</ul>"
                # html << "</ul>" unless skip_wrapper
              when Manifest::Attributes
                html << "<ul>"
                # html << "<ul>" unless skip_wrapper
                data.relevant_manifest.each_pair do |key, value|
                  if key.to_s == "type"
                    next
                  end

                  if key.to_s == "element_type_declarations"
                    key = :attributes
                    value = data.attribute_declarations
                  end
                  html << "<li>#{key} ----MANI_ATTR------"
                  # html << "<ul>"
                  html << render_html_list(value)
                  # html << "</ul>"
                  html << "</li>"
                end
                html << "</ul>"
                # html << "</ul>" unless skip_wrapper
              when Manifest::Array
                html << "<ul>"
                # html << "<ul>" unless skip_wrapper
                data.relevant_manifest.each_pair do |key, value|
                  next if key == :element_type_declaration

                  if key.to_s == "type"
                    value = root_manifest.lookup_path(key, value)
                  end
                  html << "<li>#{key} -----ARRAY_MANI------"
                  # html << "<ul>"
                  html << render_html_list(value, skip_wrapper: true)
                  # html << "</ul>"
                  html << "</li>"
                end
                html << render_html_list({ element_type: data.element_type }, skip_wrapper: true)
                html << "</ul>"
                # html << "</ul>" unless skip_wrapper
              when Manifest::TypeDeclaration
                manifest = data.relevant_manifest
                html << "<ul>"
                if manifest.is_a?(::Symbol)
                  html << "<li> -----TYPE_DEC_SYM------"
                  html << foobara_reference_link(data.to_type)
                  html << "</li>"
                else
                  # html << "<ul>"
                  # html << "<ul>" unless skip_wrapper
                  data.relevant_manifest.each_pair do |key, value|
                    if key.to_s == "type"
                      value = root_manifest.lookup_path(key, value)
                    end
                    html << "<li>#{key} -----TYPE_DEC_NON_SYM------"
                    # html << "<ul>"
                    html << render_html_list(value)
                    # html << "</ul>"
                    html << "</li>"
                  end
                  # html << "</ul>"
                  # html << "</ul>" unless skip_wrapper
                end
                html << "</ul>"
              when Manifest::Type, Manifest::Command, Manifest::Error
                html << "<ul>"
                html << "<li> ----FOOBARA_MISC------"
                html << foobara_reference_link(data)
                html << "</li>"
                html << "</ul>"
              when Manifest::PossibleError
                html << render_html_list(data.error)
              else
                html << "<ul>"
                html << "<li>#{data} -----ELSE_BLOCK-----</li>"
                html << "</ul>"
              end

              html
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
