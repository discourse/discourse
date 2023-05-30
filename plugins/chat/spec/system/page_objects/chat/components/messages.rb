# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class Messages < PageObjects::Components::Base
        attr_reader :context

        SELECTOR = ".chat-messages-scroll"

        def initialize(context)
          @context = context
        end

        def component
          find(context)
        end

        def message
          PageObjects::Components::Chat::Message.new(context + " " + SELECTOR)
        end

        def has_message?(**args)
          message.exists?(**args)
        end

        def has_no_message?(**args)
          message.does_not_exist?(**args)
        end
      end
    end
  end
end
