# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class Message < PageObjects::Components::Base
        attr_reader :context

        SELECTOR = ".chat-message-container"

        def initialize(context)
          @context = context
        end

        def does_not_exist?(**args)
          exists?(**args, does_not_exist: true)
        end

        def exists?(**args)
          text = args[:text]

          selectors = SELECTOR
          selectors += "[data-id=\"#{args[:id]}\"]" if args[:id]
          selectors += ".is-persisted" if args[:persisted]
          selectors += ".is-staged" if args[:staged]

          if args[:deleted]
            selectors += ".is-deleted"
            text = I18n.t("js.chat.deleted", count: args[:deleted])
          end

          selector_method = args[:does_not_exist] ? :has_no_selector? : :has_selector?

          if text
            find(context).send(
              selector_method,
              selectors + " " + ".chat-message-text",
              text: /#{Regexp.escape(text)}/,
            )
          else
            find(context).send(selector_method, selectors)
          end
        end
      end
    end
  end
end
