# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class ChannelRow < PageObjects::Components::Base
        SELECTOR = ".chat-channel-row"

        attr_reader :id

        def initialize(id)
          @id = id
        end

        def non_existent?(**args)
          exists?(**args, does_not_exist: true)
        end

        def exists?(**args)
          selector = build_selector(**args)
          selector_method = args[:does_not_exist] ? :has_no_selector? : :has_selector?
          page.send(selector_method, selector)
        end

        def leave
          component(class: ".can-leave").hover
          btn = component.find(".chat-channel-leave-btn", visible: :all)
          btn.click
        end

        def long_press
          row = component
          pressed = ".fk-d-menu-modal .chat-channel-sidebar-link-menu"
          page.assert_no_selector(pressed)
          page.execute_script(<<~JS, row)
            const [target] = arguments;
            const touch = new Touch({ identifier: 1, target });
            target.dispatchEvent(new TouchEvent("touchstart", {
              bubbles: true, cancelable: true, touches: [touch], changedTouches: [touch],
            }));
          JS

          begin
            page.assert_selector(pressed)
          ensure
            page.execute_script(<<~JS, row)
              const [target] = arguments;
              const touch = new Touch({ identifier: 1, target });
              target.dispatchEvent(new TouchEvent("touchend", {
                bubbles: true, cancelable: true, changedTouches: [touch],
              }));
            JS
          end
          nil
        end

        def component(**args)
          find(build_selector(**args))
        end

        private

        def build_selector(**args)
          selector = SELECTOR
          selector += args[:class] if args[:class]
          selector += "[data-chat-channel-id=\"#{id}\"]" if id
          selector
        end
      end
    end
  end
end
