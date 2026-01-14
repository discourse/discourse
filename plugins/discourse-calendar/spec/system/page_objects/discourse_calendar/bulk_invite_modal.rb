# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseCalendar
      class BulkInviteModal < PageObjects::Pages::Base
        def set_invitee_at_row(name, status, row_number)
          dropdown =
            PageObjects::Components::SelectKit.new(
              ".bulk-invite-row:nth-of-type(#{row_number}) .email-group-user-chooser",
            )
          dropdown.expand
          dropdown.search(name)
          dropdown.select_row_by_value(name)

          dropdown =
            PageObjects::Components::SelectKit.new(
              ".bulk-invite-row:nth-of-type(#{row_number}) .bulk-invite-attendance",
            )
          dropdown.expand
          dropdown.select_row_by_value(status)

          self
        end

        def add_invitee
          find(".add-bulk-invite").click
          self
        end

        def remove_invitee_row(row_number)
          find(".bulk-invite-row:nth-of-type(#{row_number}) .remove-bulk-invite").click
          self
        end

        def send_invites
          find(".send-bulk-invites").click
          self
        end

        def closed?
          has_no_css?(".post-event-bulk-invite")
        end
      end
    end
  end
end
