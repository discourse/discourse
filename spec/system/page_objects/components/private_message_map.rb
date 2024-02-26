# frozen_string_literal: true

module PageObjects
  module Components
    class PrivateMessageMap < PageObjects::Components::Base
      PRIVATE_MESSAGE_MAP_KLASS = ".private-message-map"
      def is_visible?
        has_css?(PRIVATE_MESSAGE_MAP_KLASS)
      end
    end
  end
end
