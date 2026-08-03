# frozen_string_literal: true

module PageObjects
  module Components
    module DevTools
      class MessageBusPanel < PageObjects::Components::Base
        PANEL = ".d-panel-dock.--context-dev-tools"
        CONTENT = "#{PANEL} .dev-tools-message-bus"
        ROW = "#{PANEL} .dev-tools-message-bus__row"

        def has_panel?
          page.has_css?(CONTENT)
        end

        def has_no_panel?
          page.has_no_css?(CONTENT)
        end

        def has_status?
          page.has_css?(
            "#{PANEL} .dev-tools-message-bus__chips .dev-tools-message-bus__chip.--live",
          )
        end

        def has_channel_row?(channel)
          page.has_css?(
            "#{ROW} .dev-tools-message-bus__channel-name",
            exact_text: channel,
            normalize_ws: true,
          )
        end

        def has_channel_rows?(minimum: 1)
          page.has_css?(ROW, minimum: minimum)
        end

        def expand_channel(channel)
          find(
            "#{ROW} button.dev-tools-message-bus__channel-name",
            exact_text: channel,
            normalize_ws: true,
          ).click
          self
        end

        def has_channel_detail?
          page.has_css?("#{PANEL} .dev-tools-message-bus__detail")
        end

        def has_closed_section?
          page.has_css?("#{PANEL} table.dev-tools-message-bus__closed")
        end

        def has_no_closed_section?
          page.has_no_css?("#{PANEL} table.dev-tools-message-bus__closed")
        end

        def has_closed_channel_row?(channel)
          page.has_css?(
            "#{PANEL} table.dev-tools-message-bus__closed .dev-tools-message-bus__channel-name",
            exact_text: channel,
            normalize_ws: true,
          )
        end

        def churn_subscription(channel)
          page.execute_script(
            "const handler = () => {};" \
              "window.MessageBus.subscribe('#{channel}', handler);" \
              "window.MessageBus.unsubscribe('#{channel}', handler);",
          )
          self
        end

        # Toggles through a numeric cell rather than the channel-name button,
        # proving the whole row is a click target.
        def toggle_channel_via_cell(channel)
          find(
            "#{ROW} button.dev-tools-message-bus__channel-name",
            exact_text: channel,
            normalize_ws: true,
          ).ancestor("tr").find(".dev-tools-message-bus__cell.--subscribers").click
          self
        end

        def switch_view(view)
          find("#{PANEL} .dev-tools-message-bus__view.--#{view}").click
          self
        end

        def has_stream?
          page.has_css?("#{PANEL} .dev-tools-message-bus__stream")
        end

        def close
          find("#{PANEL} .d-panel-dock__close").click
          self
        end

        def scroll_body_to_bottom
          page.execute_script(
            "const body = document.querySelector('#{PANEL} .d-panel-dock__body');" \
              "body.scrollTop = body.scrollHeight;",
          )
          self
        end

        def body_scroll_position
          page.evaluate_script("document.querySelector('#{PANEL} .d-panel-dock__body').scrollTop")
        end

        def computed_font_size(selector)
          page.evaluate_script(
            "getComputedStyle(document.querySelector('#{PANEL} #{selector}')).fontSize",
          )
        end
      end
    end
  end
end
