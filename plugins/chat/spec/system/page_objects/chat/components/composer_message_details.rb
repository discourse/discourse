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

        def has_message?(message)
          find(context).find(SELECTOR + "[data-id=\"#{message.id}\"]")
        end

        def has_no_message?
          find(context).has_no_css?(SELECTOR)
        end
      end
    end
  end
end
