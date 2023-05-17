# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class Composer < PageObjects::Components::Base
        attr_reader :context

        def initialize(context)
          @context = context
        end

        def component
          find(context).find(".chat-composer__wrapper")
        end

        def input
          component.find(".chat-composer__input")
        end

        def value
          input.value
        end

        def shiftArrowUp
          input.send_keys(%i[shift arrow_up])
        end

        def arrowUp
          input.send_keys(%i[arrow_up])
        end
      end
    end
  end
end
