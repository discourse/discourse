# frozen_string_literal: true

module AdminDashboard
  module Reports
    class Listing
      PAGE_SIZE = 30

      def self.call(cursor:, search:)
        new(cursor: cursor, search: search).call
      end

      def initialize(cursor:, search:)
        @cursor = parse_cursor(cursor)
        @search = search.presence
      end

      def call
        collected = walk_providers
        has_more = collected.size > PAGE_SIZE

        {
          providers: provider_summaries,
          items: collected.first(PAGE_SIZE).map { |entry| entry[:item].to_h },
          has_more: has_more,
          cursor: has_more ? format_cursor(collected[PAGE_SIZE]) : nil,
        }
      end

      private

      def walk_providers
        providers = Registry.providers
        start_index = @cursor ? providers.find_index { |p| p.source_name == @cursor[:source] } : 0
        walk = start_index ? providers[start_index..] : []
        current_offset = @cursor ? @cursor[:offset] : 0

        collected = []
        to_take = PAGE_SIZE + 1
        walk.each do |provider|
          break if to_take <= 0

          items = provider.list_all(search: @search, offset: current_offset, limit: to_take)
          items.each_with_index do |item, i|
            collected << { source: provider.source_name, item: item, offset: current_offset + i }
          end
          to_take -= items.size
          current_offset = 0
        end

        collected
      end

      def provider_summaries
        Registry.providers.map { |p| { source: p.source_name, label: p.label } }
      end

      def parse_cursor(raw)
        return nil if raw.blank?

        source, offset = raw.to_s.split(":", 2)
        return nil if source.blank? || offset.blank?

        offset_int = Integer(offset, 10, exception: false)
        return nil if offset_int.nil? || offset_int < 0

        { source: source, offset: offset_int }
      end

      def format_cursor(entry)
        "#{entry[:source]}:#{entry[:offset]}"
      end
    end
  end
end
