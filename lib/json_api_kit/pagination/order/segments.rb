# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Order
      class Segments
        include Enumerable

        delegate :each, :size, :last, :empty?, to: :segments

        def self.for(keyset, digest: nil) = new(Segment.split(keyset, digest:))

        def initialize(segments)
          @segments = segments
        end

        def fetch(id)
          detect { it.id == id } or raise KeyError, "This listing has no segment #{id.inspect}."
        end

        def after(segment) = self.class.new(segments.drop(place_of(segment) + 1))

        def after_every_value_of(name) = after(led_by(name))

        def locate(scope)
          lazy.filter_map { Scan.new(scope, segment: it, size: 1).rows.first }.first
        end

        def columns = flat_map(&:columns).uniq

        private

        attr_reader :segments

        def led_by(name) = detect { it.led_by?(name) }

        def place_of(segment) = segments.index { it.id == segment.id }
      end
    end
  end
end
