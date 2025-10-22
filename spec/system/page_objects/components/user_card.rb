# frozen_string_literal: true

module PageObjects
  module Components
    class UserCard < PageObjects::Components::Base
      def visible?
        has_css?("#user-card")
      end

      def showing_user?(username)
        has_css?("#user-card.user-card-#{username}")
      end
    end
  end
end
