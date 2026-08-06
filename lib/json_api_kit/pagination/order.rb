# frozen_string_literal: true

module JsonApiKit
  module Pagination
    # The order a listing is read in, as a sequence of segments: bands of rows that follow
    # one another, each with its own comparison order inside. A listing whose keys are never
    # null is one segment; a nullable leading key splits it in two, the valued rows and then
    # the null tail; a listing that puts a group first — pinned topics, say — is two with the
    # group supplied by the resource.
    #
    # Segments exist because a query that reaches the null tail cannot bound the column that
    # tail is null in, and a keyset page is only fast when the leading key is bounded. One
    # segment at a time keeps every page seekable, and a page that runs out of rows spills
    # into the segment after it.
    #
    # A cursor names the segment it was minted in before the values of the row's place within
    # that segment, so a client can be handed back to the right band of the listing.
    class Order
      attr_reader :segments

      # Only a *leading* nullable key splits a listing: anywhere else the comparison takes the
      # nulls in itself (see Predicate and Segment.split).
      def self.for(keyset) = new(Segment.split(keyset))

      def initialize(segments)
        @segments = segments
      end

      def first = segments.first

      # The segment a page spills into once this one runs out, or nothing at the end of the
      # listing.
      def after(segment) = segments[index_of(segment.id) + 1]

      def segment(id) = segments[index_of(id)]

      def reverse = self.class.new(segments.reverse.map(&:reverse))

      def position(cursor) = Position.from(cursor, order: self)

      # The first row of the listing a narrowing keeps, and where it sits — the segments are
      # walked in their own sequence, since that is the listing's order. Nothing, when no row
      # is kept: what to say about that belongs to whoever asked.
      def locate(scope, matching:)
        segments
          .lazy
          .filter_map { Scan.new(matching.call(scope), segment: it, size: 1).rows.first }
          .first
      end

      private

      # Segments are found by the identity a cursor names, never by their place: a reversed
      # order holds the same segments in the other sequence, and rebuilding an order gives
      # equal segments rather than the same objects.
      def index_of(id)
        segments.index { it.id == id } or
          raise Cursor::Invalid, "this listing has no segment #{id.inspect}"
      end
    end
  end
end
