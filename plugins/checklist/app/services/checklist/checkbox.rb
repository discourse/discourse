# frozen_string_literal: true

module Checklist
  class Checkbox
    CHECKED = "[x]"
    UNCHECKED = "[ ]"

    attr_reader :offset, :segment

    def self.permanent
      new(offset: nil, segment: nil, permanent: true)
    end

    def self.unlocated
      new(offset: nil, segment: nil, permanent: false)
    end

    def initialize(offset:, segment:, permanent:)
      @offset = offset
      @segment = segment
      @permanent = permanent
    end

    def permanent?
      @permanent
    end

    def toggleable?
      !permanent? && !offset.nil?
    end

    def checked?
      segment == CHECKED
    end

    def replace_in(raw, checked:)
      raw[0...offset] + (checked ? CHECKED : UNCHECKED) + raw[(offset + segment.length)..]
    end
  end
end
