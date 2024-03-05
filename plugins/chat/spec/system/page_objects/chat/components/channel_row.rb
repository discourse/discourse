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

        def component(**args)
          find(build_selector(**args))
        end

        private

        def build_selector(**args)
          selector = SELECTOR
          selector += args[:class] if args[:class]
          selector += "[data-chat-channel-id=\"#{self.id}\"]" if self.id
          selector
        end
      end
    end
  end
end
