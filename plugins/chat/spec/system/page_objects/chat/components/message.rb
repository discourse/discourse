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
          selectors = SELECTOR
          selectors += "[data-id=\"#{args[:id]}\"]" if args[:id]
          selectors += ".is-persisted" if args[:persisted]
          selectors += ".is-staged" if args[:staged]
          selector_method = args[:does_not_exist] ? :has_no_selector? : :has_selector?

          if args[:text]
            find(context).send(
              selector_method,
              selectors + " " + ".chat-message-text",
              text: args[:text],
            )
          else
            find(context).send(selector_method, selectors)
          end
        end
      end
    end
  end
end
