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

        def component
          find(context)
        end

        def has_message?(**args)
          PageObjects::Components::Chat::Message.new(".chat-channel").exists?(**args)
        end

        def has_no_message?(**args)
          PageObjects::Components::Chat::Message.new(".chat-channel").does_not_exist?(**args)
        end

        def has_x_messages?(count)
          find(context).has_css?(SELECTOR, count: count, visible: :all)
        end
      end
    end
  end
end
