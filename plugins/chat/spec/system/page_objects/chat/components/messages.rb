# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class Messages < PageObjects::Components::Base
        attr_reader :context

        SELECTOR = ".chat-message-container"

        def initialize(context)
          @context = context
        end

        def has_message?(id: nil, persisted: nil, text: nil, staged: nil)
          selectors = ""
          selectors += "[data-id=\"#{message.id}\"]" if id
          selectors += ".is-persisted" if persisted
          selectors += ".is-staged" if staged
          node = message(selectors)
          node.find(".chat-message-text", text: text) if text
        end

        def message(selectors = "")
          find(context).find(SELECTOR + selectors)
        end
      end
    end
  end
end
