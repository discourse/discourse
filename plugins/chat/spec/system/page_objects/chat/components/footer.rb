# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class Footer < PageObjects::Components::Base
        def has_unread_channels?
          has_css?(".c-footer #c-footer-channels .c-unread-indicator")
        end

        def has_unread_dms?(text)
          has_css?(".c-footer #c-footer-direct-messages .c-unread-indicator", text: text)
        end
      end
    end
  end
end
