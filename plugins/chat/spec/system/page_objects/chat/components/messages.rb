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

        def has_message?(**args)
          PageObjects::Components::Chat::Message.new(context + " " + SELECTOR).exists?(**args)
        end

        def has_no_message?(**args)
          !has_message?(**args)
        end
      end
    end
  end
end
