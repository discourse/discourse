# frozen_string_literal: true

module PageObjects
  module Modals
    module DiscourseEvents
      class Invitees < PageObjects::Modals::Base
        MODAL_SELECTOR = ".post-event-invitees-modal"

        def initialize
          super(body_selector: "", modal_selector: MODAL_SELECTOR)
        end

        def has_attendee?(user)
          has_css?("#{full_modal_selector} .invitees .username", text: user.username)
        end

        def has_no_attendee?(user)
          has_no_css?("#{full_modal_selector} .invitees .username", text: user.username)
        end

        def has_selected_scope?(scope)
          has_css?(
            "#{full_modal_selector} .invitees-recurrence-filter button.active",
            text: I18n.t("js.discourse_post_event.invitees_modal.#{scope}"),
            exact_text: true,
          )
        end

        def show_first_event_only
          find(
            "#{full_modal_selector} .invitees-recurrence-filter button",
            text: I18n.t("js.discourse_post_event.invitees_modal.first_event_only"),
            exact_text: true,
          ).click
          self
        end
      end
    end
  end
end
