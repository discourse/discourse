# frozen_string_literal: true

module JsonApiKit
  class Paths
    include Enumerable

    def initialize(paths)
      @paths = Array(paths).compact_blank.map { Path.for(it) }
    end

    delegate :each, :empty?, to: :paths

    def +(other) = self.class.new(to_a + other.to_a)

    def relationship_names = map(&:current).uniq

    def next_for(name) = self.class.new(select { it.current == name }.filter_map(&:next))

    private

    attr_reader :paths
  end
end
