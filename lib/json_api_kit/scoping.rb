# frozen_string_literal: true

module JsonApiKit
  class Scoping
    class All < Scoping
      def initialize = super(nil)

      def apply(scope) = scope
    end

    class PerOwner < Scoping
      def initialize(scoped_to, owner_key:)
        super(scoped_to)
        @owner_key = owner_key
      end

      def page(_requested) = Page::PerOwner.new(owner_key)

      def pairing_keys = [owner_key]

      private

      attr_reader :owner_key
    end

    def self.for(scoped_to)
      return All.new unless scoped_to
      scoped_to.try(:to_scoping) || new(scoped_to)
    end

    def initialize(scoped_to)
      @scoped_to = scoped_to
    end

    def to_scoping = self

    def apply(scope)
      narrowed = scope.merge(scoped_to.except(:where))
      return narrowed if scoped_to.where_clause.empty?
      narrowed.where(scoped_to.where_clause.ast)
    end

    def page(requested) = requested

    def pairing_keys = []

    private

    attr_reader :scoped_to
  end
end
