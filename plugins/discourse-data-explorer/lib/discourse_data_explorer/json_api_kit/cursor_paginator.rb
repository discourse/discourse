# frozen_string_literal: true

require "pagy"
# Pagy autoloads its classes lazily and Pagy::B64 is only defined by keyset.rb —
# without this eager require, a bare `encode_cursor` call before anything touches
# Pagy::Keyset raises NameError (bit us as a spec-order-dependent CI flake).
require "pagy/classes/keyset/keyset"

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
    # Any keyset key may be backed by SQL rather than a column: pass
    # `expressions: { key => "<sql>" }` (plus `joins:` if the SQL needs them) and
    # the value is projected as `<sql> AS key` behind a subquery, so ordering,
    # keyset predicates and cursor minting all work on it unchanged. That covers
    # joined values (`users.username`), computed ones (a `CASE` expression), and
    # the composed mixed-direction keysets core PR #36065 builds by hand.
    #
    # Nullable keys are handled by `nulls_last:`: each listed key gets a
    # `<key>_is_null` CASE helper prepended to the keyset, which sorts NULLs last
    # and keeps them reachable. The helper is computed from the key's SQL when it
    # has one — an alias cannot be referenced in the SELECT that defines it.
    # See docs/jsonapi-spec-reference.md §8.2.
    class CursorPaginator
      InvalidCursor = Class.new(StandardError)
      AnchorNotFound = Class.new(StandardError)

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
          Pagy::B64.urlsafe_encode(
            record.slice(*order.keys).values.map { encode_value(it) }.to_json,
          )
        end

        # `Time#to_json` truncates to milliseconds while Postgres keeps
        # microseconds, so a cursor minted from a sub-millisecond timestamp
        # compares as *earlier* than its own row — the row repeats, or its
        # neighbour is skipped. Encode timestamps at full precision instead.
        def encode_value(value)
          value.is_a?(Time) || value.is_a?(DateTime) ? value.iso8601(6) : value
        end
      end

      def initialize(
        scope,
        order:,
        size:,
        after: nil,
        before: nil,
        nulls_last: [],
        expressions: {},
        joins: [],
        around: nil
      )
        @around = around
        @expressions = expressions.transform_keys(&:to_sym)
        @joins = Array(joins)
        @null_helpers = (nulls_last.map(&:to_sym) & order.keys).to_h { [it, :"#{it}_is_null"] }
        @order = expand_order(order)
        @scope = prepare_scope(scope)
        @size = size
        @after = validate_cursor!(after)
        @before = validate_cursor!(before)
        # Kept so an anchor can spawn a sibling paginator (see #anchor_cursor).
        @source_scope = scope
        @source_options = { order:, nulls_last:, expressions:, joins: }
      end

      # Positional entry (docs/versioning-design.md §2c). The block selects the
      # anchor ROW, which the caller hands back as `around:` to get a window centred
      # on it (`before`/`after` counts, `include` for the row itself).
      def anchor_record
        yield(@scope).reorder(@order).first or raise AnchorNotFound
      end

      # The block selects the anchor ROW — by identity, by a bound on the leading ordering column, or by
      # anything else the resource declares — and the cursor is minted from that
      # row, never built from the supplied value. That is what makes anchoring work
      # against composed keysets whose leading column is synthetic (core PR #36065's
      # `sort_priority`), and against groups no value can name (the NULL tail).
      #
      # Returns the cursor of the row *preceding* the anchor, so feeding it back as
      # `after:` yields a window starting AT the anchor with the ordinary window,
      # link and probe machinery untouched. `nil` means the anchor is the first row.
      def anchor_cursor
        record = yield(@scope).reorder(@order).first or raise AnchorNotFound
        predecessor =
          self
            .class
            .new(@source_scope, **@source_options, size: 1, before: cursor_for(record))
            .records
            .first
        predecessor && cursor_for(predecessor)
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
              self.class.encode_value(record.public_send(key))
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

      # One subquery projects every keyset value that isn't already a column of the
      # table — expression-backed keys and NULL helpers alike — aliased as the table
      # so the outer query can order, predicate and read them.
      def prepare_scope(scope)
        return scope if @null_helpers.empty? && @expressions.empty?

        model = scope.klass
        connection = model.connection
        table = connection.quote_table_name(model.table_name)
        selects = @expressions.map { |key, sql| "#{sql} AS #{connection.quote_column_name(key)}" }
        selects +=
          @null_helpers.map do |key, helper|
            "CASE WHEN #{key_sql(key, table:, connection:)} IS NULL " \
              "THEN 1 ELSE 0 END AS #{connection.quote_column_name(helper)}"
          end
        inner = @joins.empty? ? scope : scope.joins(*@joins)
        inner = inner.select("#{table}.*", *selects)
        model.select("*").from(inner, model.table_name)
      end

      def key_sql(key, table:, connection:)
        @expressions[key] || "#{table}.#{connection.quote_column_name(key)}"
      end

      def window
        @window ||=
          if @around
            around_window
          elsif @before
            before_window
          else
            after_window
          end
      end

      # Two ordinary windows hugging the anchor from either side, concatenated —
      # so a permalink gets its context in one request. Each side's own probe answers
      # whether there is more beyond it.
      def around_window
        anchor = @around[:record]
        cursor = cursor_for(anchor)
        before_records, prev_exists = side(size: @around[:before], before: cursor)
        after_records, next_exists = side(size: @around[:after], after: cursor)
        {
          records: before_records + (@around[:include] ? [anchor] : []) + after_records,
          prev_exists:,
          next_exists:,
        }
      end

      # A zero-sized side is not a query: probe whether anything lies that way.
      def side(size:, before: nil, after: nil)
        if size.to_i.zero?
          order = before ? reversed_order : @order
          return [], probe_exists?(order, before || after)
        end
        sibling = self.class.new(@source_scope, **@source_options, size:, before:, after:)
        exists = before ? sibling.prev_page_params.present? : sibling.next_page_params.present?
        [sibling.records.to_a, exists]
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
