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

        def exists?(**args)
          selectors = SELECTOR
          selectors += "[data-id=\"#{args[:id]}\"]" if args[:id]
          selectors += ".is-persisted" if args[:persisted]
          selectors += ".is-staged" if args[:staged]

          if args[:text]
            find(context).has_selector?(selectors + " " + ".chat-message-text", text: args[:text])
          else
            find(context).has_selector?(selectors)
          end
        end
      end
    end
  end
end
