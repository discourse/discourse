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

    def single_value? = !without_value? && !value.is_a?(Enumerable)

    def without_value? = value.nil?
  end
end
