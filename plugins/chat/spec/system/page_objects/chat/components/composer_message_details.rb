# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class ComposerMessageDetails < PageObjects::Components::Base
        attr_reader :context

        SELECTOR = ".chat-composer-message-details"

        def initialize(context)
          @context = context
        end

        def component
          find(context)
        end

        def has_message?(id: nil, action: nil, text: nil)
          selectors = SELECTOR
          selectors += "[data-id=\"#{id}\"]" if id
          selectors += "[data-action=\"#{action}\"]" if action
          component.has_css?(selectors, exact_text: text)
        end

        def has_no_message?(**args)
          !has_message?(**args)
        end

        def editing?(message)
          has_message?(id: message.id, action: :edit)
        end

        def replying_to?(message)
          has_message?(id: message.id, action: :reply)
        end
      end
    end
  end
end
