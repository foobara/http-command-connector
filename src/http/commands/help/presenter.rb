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

            def render_html_parent(data)
              # This function is the parent function of render_html_list just to eliminate the skip_wrapper mechanism.
              # This function eliminates the need to use <ul> tags in the render_html_list function calls.
              # Note that we are making some calls on render_html_list function but eliminating the need for skip_wrapper.
              html = ""
              case data
                when ::Hash
                  html << "<ul>"
                  data.each do |key,value|
                    html << "<li>"
                    html << "<strong>#{key}: </strong>"
                    html << foobara_reference_link(value.error)
                    html << "</li>"
                  end
                  html << "</ul>"
                when Manifest::Attributes
                  html << "<ul>"
                  data.relevant_manifest.each_pair do |key, value|
                    if key.to_s == "type"
                      next
                    end
                    if key.to_s == "element_type_declarations"
                      key = :attributes
                      value = data.attribute_declarations
                    end
                    html << "<li>"
                    html << "<strong>#{key}: </strong>"
                    html << "<ul>"
                    html << render_html_list(value)
                    html << "</ul>"
                    html << "</li>"
                  end
                  html << "</ul>"
                when Manifest::TypeDeclaration
                  manifest = data.relevant_manifest
                  if manifest.is_a?(::Symbol)
                    html << "<strong>Result Type: </strong>"
                    html << foobara_reference_link(data.to_type)
                  end
                    
              end
              html
            end

            def render_html_list(data)
              html = ""
              case data
              when ::Hash
                data.each do |key, value|
                  html << "<li><strong>#{key} </strong>"
                  html << "<ul>"
                  html << render_html_list(value)
                  html << "</ul>"
                  html << "</li>"
                end
              when ::Array
                data.each do |item|
                  html << render_html_list(item)
                end
              when Manifest::Array
                data.relevant_manifest.each_pair do |key, value|
                  next if key == :element_type_declaration

                  if key.to_s == "type"
                    value = root_manifest.lookup_path(key, value)
                  end
                  html << "<li>#{key}"
                  html << "<ul>"
                  html << render_html_list(value)
                  html << "</ul>"
                  html << "</li>"
                end
                html << render_html_list({ element_type: data.element_type })
              when Manifest::TypeDeclaration
                manifest = data.relevant_manifest

                if manifest.is_a?(::Symbol)
                  html << "<li><strong>type: </strong>"
                  html << foobara_reference_link(data.to_type)
                  html << "</li>"
                else
                  data.relevant_manifest.each_pair do |key, value|
                    if key.to_s == "type"
                      value = root_manifest.lookup_path(key, value)
                    end
                    html << "<li><strong>#{key}: </strong>"
                    html << render_html_list(value)
                    html << "</li>"
                  end
                end
              when Manifest::Type
                html << foobara_reference_link(data)
              when Manifest::Command
                html << "<li><strong>COMMAND: </strong>"
                html << foobara_reference_link(data)
                html << "</li>"
              when String
                html << data
              when true,false
                html << data.to_s
              else
                html << "<li>#{data}</li>"
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
