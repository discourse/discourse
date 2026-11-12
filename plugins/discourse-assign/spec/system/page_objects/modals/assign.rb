# frozen_string_literal: true

module PageObjects
  module Modals
    class Assign < PageObjects::Modals::Base
      def assignee=(assignee)
        assignee = assignee.is_a?(Group) ? assignee.name : assignee.username
        assignee_chooser.search(assignee)
        assignee_chooser.select_row_by_value(assignee)
      end

      def select_assignee_with_keyboard(assignee)
        assignee = assignee.is_a?(Group) ? assignee.name : assignee.username
        input = find(".control-group input")
        input.fill_in(with: assignee)
        find("li[data-value='#{assignee}'].is-highlighted")
        input.send_keys(:enter)
      end

      def status=(status)
        find("#assign-status").click
        find("[data-value='#{status}']").click
      end

      def note=(note)
        find("#assign-modal-note").fill_in(with: note)
      end

      def confirm
        find(".d-modal__footer .btn-primary").click
      end

      private

      def assignee_chooser
        @assignee_chooser ||= PageObjects::Components::SelectKit.new("#assignee-chooser")
      end
    end
  end
end
