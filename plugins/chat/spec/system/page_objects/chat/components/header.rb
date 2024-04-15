# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class Header < PageObjects::Components::Base
        def has_open_chat_button?
          has_css?(".d-header .chat-header-icon .d-icon-d-chat")
        end

        def has_open_forum_button?
          has_css?(".d-header .chat-header-icon .d-icon-random")
        end

        def has_no_chat_button?
          has_no_css?(".d-header .chat-header-icon")
        end
      end
    end
  end
end
