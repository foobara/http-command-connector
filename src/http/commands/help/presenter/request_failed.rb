module Foobara
  module CommandConnectors
    class Http < CommandConnector
      module Commands
        class Help < Command
          class Presenter
            class RequestFailed < Presenter
            end
          end
        end
      end
    end
  end
end
