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

        def has_message?(**args)
          selectors = SELECTOR
          selectors += "[data-id=\"#{args[:id]}\"]" if args[:id]
          selectors += "[data-action=\"#{args[:action]}\"]" if args[:action]
          selector_method = args[:does_not_exist] ? :has_no_selector? : :has_selector?

          component.send(selector_method, selectors)
        end

        def has_no_message?(**args)
          has_message?(**args, does_not_exist: true)
        end

        def editing?(message)
          has_message?(id: message.id, action: :edit)
        end

        def replying_to?(message)
          has_message?(id: message.id, action: :reply)
        end

        def cancel_edit
          component.find(".cancel-message-action").click
        end
      end
    end
  end
end
