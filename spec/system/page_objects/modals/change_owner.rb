# frozen_string_literal: true

module PageObjects
  module Modals
    class ChangeOwner < PageObjects::Pages::Base
      USERS_DROPDOWN = ".select-kit"

      def modal
        find(".change-ownership-modal")
      end

      def select_new_owner(user)
        within(modal) do
          users_dropdown.expand
          users_dropdown.search(user.username)
          users_dropdown.select_row_by_value(user.username)
        end
      end

      def confirm_new_owner
        within(modal) { find(".d-modal__footer .btn").click }
      end

      def users_dropdown
        @users_dropdown ||= PageObjects::Components::SelectKit.new(USERS_DROPDOWN)
      end
    end
  end
end
