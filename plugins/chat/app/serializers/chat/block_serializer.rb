# frozen_string_literal: true

module Chat
  class BlockSerializer < ApplicationSerializer
    attributes :type, :elements

    def type
      object["type"]
    end

    def elements
      object["elements"].map do |element|
        serializer = self.class.element_serializer_for(element["type"])
        serializer.new(element, root: false).as_json
      end
    end

    def self.element_serializer_for(type)
      case type
      when "button"
        Chat::Blocks::Elements::ButtonSerializer
      else
        raise "no serializer for #{type}"
      end
    end
  end
end
