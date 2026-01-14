# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseCalendar
      class PostEvent < PageObjects::Pages::Base
        TRIGGER_MENU_SELECTOR = ".discourse-post-event-more-menu-trigger"
        def open_more_menu
          find(TRIGGER_MENU_SELECTOR).click
          self
        end

        def going
          find(".going-button").click
          self
        end

        def open_bulk_invite_modal
          open_more_menu
          find(".dropdown-menu__item.bulk-invite").click
          self
        end

        def has_location?(text)
          has_css?(".event-location", text:)
        end

        def has_description?(text)
          has_css?(".event-description", text:)
        end

        def close
          has_css?(".discourse-post-event .status-and-creators .status:not(.closed)")
          open_more_menu
          find(".close-event").click
          find("#dialog-holder .btn-primary").click
          has_css?(".discourse-post-event .status-and-creators .status.closed")
          has_no_css?("#{TRIGGER_MENU_SELECTOR}.--saving")
          self
        end

        def open
          has_css?(".discourse-post-event .status-and-creators .status.closed")
          open_more_menu
          find(".open-event").click
          find("#dialog-holder .btn-primary").click
          has_css?(".discourse-post-event .status-and-creators .status:not(.closed)")
          has_no_css?("#{TRIGGER_MENU_SELECTOR}.--saving")
          self
        end

        def edit
          open_more_menu
          find(".edit-event").click
        end
      end
    end
  end
end
