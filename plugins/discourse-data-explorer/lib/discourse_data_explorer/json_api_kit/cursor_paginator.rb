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
    # prev/next, and per-item cursors minted by mirroring Pagy's own cutoff
    # derivation (item and page cursors are interchangeable). `order` must be a
    # total order (append a unique tiebreak such as `id`).
    #
    # Nullable keyset columns are handled by `nulls_last:`: each listed column
    # gets a `<column>_is_null` CASE helper prepended to the keyset (the scope
    # is wrapped in a subquery aliased as the table so the helper is orderable,
    # predicable and readable — core PR #36065's trick), which sorts NULLs last
    # and keeps them reachable. See docs/jsonapi-spec-reference.md §8.2.
    class CursorPaginator
      InvalidCursor = Class.new(StandardError)

      # Stock Pagy composes equality with `=`, so a cursor minted on a NULL-valued
      # row stops matching and the NULL tail becomes unreachable. Same predicate,
      # null-safe equality. Verbatim copy of Pagy::Keyset#compose_predicate
      # (43.6.0) with `=` → `IS NOT DISTINCT FROM` — upstream candidate.
      class NullSafeEngine < Pagy::Keyset::ActiveRecord
        mix_in_adapter("ActiveRecord")

        # The parent's factory constructor re-dispatches by class name; bypass it.
        def self.new(set, **) = allocate.tap { it.send(:initialize, set, **) }

        protected

        def compose_predicate(prefix = nil)
          operator = { asc: ">", desc: "<" }
          directions = @keyset.values
          identifier = @identifiers
          placeholder = @keyset.to_h { |column| [column, ":#{prefix}#{column}"] }

          if @options[:tuple_comparison] && (directions.all?(:asc) || directions.all?(:desc))
            return(
              "(#{identifier.values.join(", ")}) #{operator[directions.first]} (#{placeholder.values.join(", ")})"
            )
          end

          keyset = @keyset.to_a
          ors = []
          until keyset.empty?
            column, direction = keyset.pop
            ands = keyset.map { |k, _| "#{identifier[k]} IS NOT DISTINCT FROM #{placeholder[k]}" }
            ands << "#{identifier[column]} #{operator[direction]} #{placeholder[column]}"
            ors << "(#{ands.join(" AND ")})"
          end
          query = ors.join(" OR ")

          return query if @keyset.size <= 1

          column, direction = @keyset.first
          hint = "#{identifier[column]} #{operator[direction]}= #{placeholder[column]}"
          "#{hint} AND (#{query})"
        end
      end

      class << self
        # Mirrors Pagy's own cutoff derivation (keyset attribute values → JSON →
        # B64), so an item cursor is interchangeable with a page cursor.
        def encode_cursor(record, order:)
          Pagy::B64.urlsafe_encode(record.slice(*order.keys).values.to_json)
        end
      end

      def initialize(scope, order:, size:, after: nil, before: nil, nulls_last: [])
        @null_helpers = (nulls_last.map(&:to_sym) & order.keys).to_h { [it, :"#{it}_is_null"] }
        @order = expand_order(order)
        @scope = prepare_scope(scope)
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

      # Null helpers are computed from the source column, so cursors can be minted
      # for any record — not only ones fetched through the wrapped scope.
      def cursor_for(record)
        values =
          @order.keys.map do |key|
            if (column = @null_helpers.key(key))
              record.public_send(column).nil? ? 1 : 0
            else
              record.public_send(key)
            end
          end
        Pagy::B64.urlsafe_encode(values.to_json)
      end

      private

      # `{ last_run_at: :desc }` with nulls-last → `{ last_run_at_is_null: :asc,
      # last_run_at: :desc }` — the 0/1 helper groups NULLs after the values and
      # is JSON-native, so cursors need no extra typecasting.
      def expand_order(order)
        order.each_with_object({}) do |(column, direction), expanded|
          expanded[@null_helpers[column]] = :asc if @null_helpers[column]
          expanded[column] = direction
        end
      end

      def prepare_scope(scope)
        return scope if @null_helpers.empty?

        model = scope.klass
        connection = model.connection
        table = connection.quote_table_name(model.table_name)
        helper_selects =
          @null_helpers.map do |column, helper|
            "CASE WHEN #{table}.#{connection.quote_column_name(column)} IS NULL " \
              "THEN 1 ELSE 0 END AS #{connection.quote_column_name(helper)}"
          end
        model.select("*").from(scope.select("#{table}.*", *helper_selects), model.table_name)
      end

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
        NullSafeEngine.new(@scope.reorder(order), keyset: order, page: page, limit: limit)
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
