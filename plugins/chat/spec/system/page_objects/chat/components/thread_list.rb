# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class ThreadList < PageObjects::Components::Base
        SELECTOR = ".chat-thread-list"

        def component
          find(SELECTOR)
        end

        def has_loaded?
          component.has_css?(".spinner", wait: 0)
          component.has_no_css?(".spinner")
        end
      end
    end
  end
end
