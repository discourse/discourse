# frozen_string_literal: true

require "pagy"

module DiscourseDataExplorer
  module JsonApiKit
    # Keyset pagination per the JSON:API cursor-pagination profile
    # (https://jsonapi.org/profiles/ethanresnick/cursor-pagination), with
    # Pagy::Keyset as the engine — it composes optimized predicates for
    # composite, mixed-direction keysets (the future List/Topic workload, see
    # core PR #36065), and handles cursor typecasting. This adapter layers on
    # what the profile needs: reverse (`before`) windows, null-accurate
    # prev/next, and per-item cursors. `order` must be a total order (append a
    # unique tiebreak such as `id`). See docs/jsonapi-spec-reference.md §8.2.
    class CursorPaginator
      InvalidCursor = Class.new(StandardError)

      class << self
        # Mirrors Pagy's own cutoff derivation (keyset attribute values → JSON →
        # B64), so an item cursor is interchangeable with a page cursor.
        def encode_cursor(record, order:)
          Pagy::B64.urlsafe_encode(record.slice(*order.keys).values.to_json)
        end
      end

      def initialize(scope, order:, size:, after: nil, before: nil)
        @scope = scope
        @order = order
        @size = size
        @after = validate_cursor!(after)
        @before = validate_cursor!(before)
      end

      def records = window[:records]

      # Query params for the profile's prev/next links; nil means the link is null
      # (no such page). An empty window still points back/forward at the cursor
      # itself, so a client can always escape an empty page.
      def prev_page_params
        return if !window[:prev_exists]
        { before: records.first ? cursor_for(records.first) : @after }
      end

      def next_page_params
        return if !window[:next_exists]
        { after: records.last ? cursor_for(records.last) : @before }
      end

      def cursor_for(record) = self.class.encode_cursor(record, order: @order)

      private

      def window
        @window ||= @before ? before_window : after_window
      end

      def after_window
        engine = build_engine(@order, page: @after)
        records = engine.records
        {
          records: records,
          next_exists: !engine.next.nil?,
          prev_exists:
            probe_exists?(reversed_order, records.first ? cursor_for(records.first) : @after),
        }
      end

      # Fetched along the reversed order so the window hugs the cursor, then
      # flipped back to presentation order.
      def before_window
        engine = build_engine(reversed_order, page: @before)
        records = engine.records.reverse
        {
          records: records,
          prev_exists: !engine.next.nil?,
          next_exists: probe_exists?(@order, records.last ? cursor_for(records.last) : @before),
        }
      end

      def build_engine(order, page:, limit: @size)
        Pagy::Keyset.new(@scope.reorder(order), keyset: order, page: page, limit: limit)
      end

      def probe_exists?(order, cursor)
        return false if cursor.nil?
        build_engine(order, page: cursor, limit: 1).records.any?
      end

      def reversed_order
        @reversed_order ||= @order.transform_values { it == :asc ? :desc : :asc }
      end

      def validate_cursor!(raw)
        return if raw.blank?

        values = Pagy::Keyset.decode(raw)
        if !values.is_a?(Array) || values.size != @order.size
          raise InvalidCursor, "invalid cursor: #{raw.inspect}"
        end
        raw
      end
    end
  end
end
