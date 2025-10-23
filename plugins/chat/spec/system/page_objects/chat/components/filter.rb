# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class Filter < PageObjects::Components::Base
        def filter_bar
          @filter_bar ||= locator(".chat-channel__filter-bar")
        end

        def available?
          expect(locator(".c-navbar__filter")).to be_visible
        end

        def not_available?
          expect(locator(".c-navbar__filter")).to be_hidden
        end

        def toggle
          locator(".c-navbar__filter").click(position: { x: 0, y: 25 }) # avoid mini profiler
          self
        end

        def not_visible?
          expect(filter_bar).to be_hidden
        end

        def visible?
          expect(filter_bar).to be_visible
        end

        def fill_in(query)
          filter_bar.locator("input").fill(query)
          self
        end

        def clear
          filter_bar.locator(".filter-input-clear-btn").click
          self
        end

        def has_no_state?
          has_no_css?(".chat-channel__filter-position")
        end

        def has_no_results?
          has_css?(".alert.alert-info", text: I18n.t("js.chat.search.no_results"))
        end

        def has_state?(results: nil, position: nil)
          filter_bar.locator(".chat-channel__filter-position-total", hasText: results) &&
            filter_bar.locator(".chat-channel__filter-position-index", hasText: position)
        end

        def navigate_to_previous_result
          filter_bar.locator(".chat-channel__prev-result").click
          self
        end

        def navigate_to_next_result
          filter_bar.locator(".chat-channel__next-result").click
          self
        end
      end
    end
  end
end
