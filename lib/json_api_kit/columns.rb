# frozen_string_literal: true

module JsonApiKit
  class Columns
    class << self
      def all = All.new

      def for(names)
        return all if names.include?(nil)
        new(names)
      end
    end

    def initialize(names)
      @names = names.uniq
    end

    def apply(scope) = scope.select(*names)

    def with(*more) = Columns.for(names + more)

    def ==(other) = other.instance_of?(self.class) && other.names == names

    alias eql? ==

    def hash = [self.class, names].hash

    protected

    attr_reader :names
  end
end
