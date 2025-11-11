# frozen_string_literal: true

module PageObjects
  module Modals
    class Assign < PageObjects::Modals::Base
      def assignee=(assignee)
        assignee = assignee.is_a?(Group) ? assignee.name : assignee.username
        find(".control-group input").fill_in(with: assignee)
        find("li[data-value='#{assignee}']").click
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
    end
  end
end
