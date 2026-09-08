# frozen_string_literal: true

module JsonApiKit
  class Joins
    class << self
      def for(declarations)
        return declarations if declarations.is_a?(self)
        new(Array.wrap(declarations))
      end
    end

    def initialize(declarations)
      @declarations = declarations.uniq
    end

    def apply(scope) = scope.joins(statements).left_outer_joins(associations)

    def +(other) = self.class.new(declarations + other.declarations)

    def ==(other) = other.instance_of?(self.class) && other.declarations == declarations

    alias eql? ==

    def hash = [self.class, declarations].hash

    protected

    attr_reader :declarations

    private

    def statements = declarations.grep(String)

    def associations = declarations - statements
  end
end
