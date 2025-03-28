module Foobara
  module CommandConnectors
    class Http < CommandConnector
      module Commands
        class Help < Command
          class ResultSerializer < Serializer
            def serialize(object_to_help_with)
              presenter = Presenter.for(object_to_help_with)

              template_path = presenter.template_path
              template_body = File.read(template_path)
              template = ERB.new(template_body)
              template.filename = template_path

              template.result(presenter.instance_eval { binding })
            end
          end
        end
      end
    end
  end
end
