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

        def has_message?(message, action: nil)
          data_attributes = "[data-id=\"#{message.id}\"]"
          data_attributes << "[data-action=\"#{action}\"]" if action
          component.find(SELECTOR + data_attributes)
        end

        def has_no_message?
          component.has_no_css?(SELECTOR)
        end

        def editing_message?(message)
          has_message?(message, action: :edit)
        end

        def cancel_edit
          component.find(".cancel-message-action").click
        end
      end
    end
  end
end
