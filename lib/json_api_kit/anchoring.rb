# frozen_string_literal: true

module JsonApiKit
  class Anchoring
    class << self
      def for(anchor)
        name, value = Array(anchor).first
        name && new(name.to_s, value)
      end
    end

    attr_reader :name, :value

    def initialize(name, value)
      @name = name
      @value = value
    end
  end
end
