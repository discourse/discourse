# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseCalendar
      class PostEventForm < PageObjects::Pages::Base
        MODAL_SELECTOR = ".post-event-builder-modal"

        def fill_location(with)
          form.find(".event-field.location input").fill_in(with:)
          self
        end

        def fill_description(with)
          form.find(".event-field.description textarea").fill_in(with:)
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
