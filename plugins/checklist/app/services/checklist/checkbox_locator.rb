# frozen_string_literal: true

module Checklist
  class CheckboxLocator
    def self.call(raw:, cooked: nil)
      new(raw:, cooked:).call
    end

    def initialize(raw:, cooked: nil)
      @raw = raw
      @cooked = cooked
    end

    def call
      if @cooked.present?
        checkboxes = extract(@cooked)
        if checkboxes.all? { |checkbox| checkbox.permanent? || checkbox.toggleable? }
          return checkboxes
        end
      end

      extract(PrettyText.cook(@raw))
    end

    private

    def extract(cooked)
      Nokogiri::HTML5.fragment(cooked).css("span.chcklst-box").map { |node| build(node) }
    end

    def build(node)
      return Checkbox.permanent if permanent?(node)

      normalized_offset = node["data-chk-off"]
      return Checkbox.unlocated if normalized_offset.blank?

      offset = raw_offset_for(normalized_offset.to_i)
      segment = segment_at(offset)
      return Checkbox.unlocated if segment.nil?

      Checkbox.new(offset:, segment:, permanent: false)
    end

    def permanent?(node)
      node.classes.include?("permanent")
    end

    TOGGLEABLE_SEGMENTS = [Checkbox::UNCHECKED, Checkbox::CHECKED].freeze

    def segment_at(offset)
      three = @raw[offset, 3]
      return three if TOGGLEABLE_SEGMENTS.include?(three)

      two = @raw[offset, 2]
      two == "[]" ? two : nil
    end

    def raw_offset_for(normalized_offset)
      return normalized_offset if @raw.exclude?("\r")

      chars = @chars ||= @raw.chars
      raw_index = 0
      normalized_index = 0

      while normalized_index < normalized_offset && raw_index < chars.length
        if chars[raw_index] == "\r"
          raw_index += 1
          raw_index += 1 if chars[raw_index] == "\n"
        else
          raw_index += 1
        end
        normalized_index += 1
      end

      raw_index
    end
  end
end
