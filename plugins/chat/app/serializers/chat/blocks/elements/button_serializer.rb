# frozen_string_literal: true

module Chat
  module Blocks
    module Elements
      class ButtonSerializer < ApplicationSerializer
        attributes :action_id, :type, :text, :style, :icon

        def action_id
          object["action_id"]
        end

        def type
          object["type"]
        end

        def style
          object["style"]
        end

        def icon
          object["icon"]
        end

        def text
          Chat::Blocks::Elements::TextSerializer.new(object["text"], root: false).as_json
        end
      end
    end
  end
end
