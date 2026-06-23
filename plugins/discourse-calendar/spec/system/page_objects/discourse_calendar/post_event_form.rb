# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseCalendar
      class PostEventForm < PageObjects::Pages::Base
        MODAL_SELECTOR = ".post-event-builder-modal"

        def fill_location(with)
          modal.find(".composer-event__location-input").fill_in(with:)
          self
        end

        def fill_description(with)
          modal.find(".composer-event__description-textarea").fill_in(with:)
          self
        end

        def fill_timezone(with)
          open_advanced
          filter =
            PageObjects::Components::SelectKit.new(".post-event-builder-modal .timezone-input")
          filter.search(with)
          filter.select_row_by_value(with)
          self
        end

        def open_advanced
          if modal.has_css?(".d-modal__footer .advanced-mode-btn", wait: 0)
            modal.find(".d-modal__footer .advanced-mode-btn").click
          end
          self
        end

        def form
          modal.find("form")
        end

        def modal
          find(MODAL_SELECTOR)
        end

        def submit
          modal.find(".d-modal__footer .btn-primary").click
          has_no_selector?(MODAL_SELECTOR)
          self
        end
      end
    end
  end
end
