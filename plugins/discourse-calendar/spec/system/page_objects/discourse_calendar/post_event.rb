# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseCalendar
      class PostEvent < PageObjects::Pages::Base
        TRIGGER_MENU_SELECTOR = ".discourse-post-event-more-menu-trigger"

        def open_more_menu
          # post-event component re-renders on a post re-cook and message_bus
          # events, so we need to retry on stale refs (hence `synchronize`)
          page.document.synchronize { find("#{TRIGGER_MENU_SELECTOR}:not(.--saving)").click }

          has_css?(".discourse-post-event-more-menu-content")
          self
        end

        def going
          page.document.synchronize { find(".going-button").click }
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

        def has_no_description?
          has_no_css?(".event-description")
        end

        def has_description_toggle?
          has_css?(".event-description__toggle")
        end

        def has_no_description_toggle?
          has_no_css?(".event-description__toggle")
        end

        def click_description_toggle
          find(".event-description__toggle").click
          self
        end

        def has_description_clamped?
          has_css?(".event-description.is-clamped:not(.is-expanded)")
        end

        def has_description_expanded?
          has_css?(".event-description.is-clamped.is-expanded")
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

        def add_to_calendar
          open_more_menu
          find(".add-to-calendar .btn").click
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
