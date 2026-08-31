# frozen_string_literal: true

module JsonApiKit
  class Path
    SEPARATOR = "."

    def self.for(path) = path.try(:to_path) || new(path.to_s.split(SEPARATOR))

    def initialize(names, at: 0)
      @names = names
      @at = at
    end

    def to_path = self

    def current = names[at]

    def last? = at == names.size - 1

    def entered? = at.positive?

    def next
      return if last?
      self.class.new(names, at: at + 1)
    end

    def to_s = names.join(SEPARATOR)

    def ==(other) = other.is_a?(self.class) && names == other.names && at == other.at

    alias eql? ==

    def hash = [names, at].hash

    protected

    attr_reader :names, :at
  end
end
