# frozen_string_literal: true

module Chat
  module Blocks
    module Elements
      class TextSerializer < ApplicationSerializer
        attributes :text, :type

        def type
          object["type"]
        end

        def text
          object["text"]
        end
      end
    end
  end
end
