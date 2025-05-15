# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class Message < PageObjects::Components::Base
        attr_reader :context
        attr_reader :component

        SELECTOR = ".chat-message-container"

        def initialize(context)
          @context = context
        end

        def does_not_exist?(**args)
          exists?(**args, does_not_exist: true)
        end

        def hover
          component.hover
        end

        def open_more_menu
          hover
          click_more_button
        end

        def expand
          component.find(".chat-message-expand").click
        end

        def secondary_action(action)
          if page.has_css?("html.mobile-view", wait: 0)
            open_mobile_actions
            page.find(".chat-message-actions [data-id=\"#{action}\"]").click
          else
            open_more_menu
            page.find("[data-value='#{action}']").click
          end
        end

        def open_mobile_actions
          page.execute_script(<<-JS, component)
            arguments[0].dispatchEvent(new TouchEvent("touchstart", {
              cancelable: true,
              bubbles: true,
              touches: [
                new Touch({ identifier: Date.now(), target: arguments[0] })
              ],
            }));


            setTimeout(() => {
              arguments[0].dispatchEvent(new TouchEvent("touchend", {
                cancelable: true,
                bubbles: true,
                touches: [
                  new Touch({ identifier: Date.now(), target: arguments[0] })
                ],
              }));
            }, 600);
          JS
        end

        def bookmark
          if page.has_css?("html.mobile-view", wait: 0)
            secondary_action("bookmark")
          else
            hover
            page.find(".chat-message-actions .bookmark-btn").click
          end
        end

        def emoji(code)
          if page.has_css?("html.mobile-view", wait: 0)
            open_mobile_actions
          else
            hover
          end

          page.find(".chat-message-actions [data-emoji-name='#{code}']").click
        end

        def select(shift: false)
          if component[:class].include?("-selectable")
            message_selector = component.find(".chat-message-selector")
            if shift
              message_selector.click(:shift)
            else
              message_selector.click
            end

            return
          end

          secondary_action("select")
        end

        def find(**args)
          selector = build_selector(**args)
          text = args[:text]
          text = I18n.t("js.chat.deleted", count: args[:deleted]) if args[:deleted]

          @component =
            page.find("#{context} #{selector}", text: text ? /#{Regexp.escape(text)}/ : nil)

          self
        end

        def exists?(**args)
          selector = build_selector(**args)
          text = args[:text]
          text = I18n.t("js.chat.deleted", count: args[:deleted]) if args[:deleted]

          selector_method = args[:does_not_exist] ? :has_no_selector? : :has_selector?

          if text
            page.find(context).send(
              selector_method,
              selector + " " + ".chat-message-text",
              (args[:exact] ? :exact_text : :text) => text,
            )
          else
            page.find(context).send(selector_method, selector)
          end
        end

        private

        def click_more_button
          page.find(".more-buttons").click
        end

        def build_selector(**args)
          selector = SELECTOR

          if args[:not_processed]
            selector += ".-not-processed"
          else
            selector += ".-processed.-persisted"
          end

          selector += "[data-id=\"#{args[:id]}\"]" if args[:id]
          selector += ".-selected" if args[:selected]
          selector += ".-persisted" if args[:persisted]
          selector += ".-staged" if args[:staged]
          selector += ".-deleted" if args[:deleted]
          selector += ".-highlighted" if args[:highlighted]
          selector
        end
      end
    end
  end
end
