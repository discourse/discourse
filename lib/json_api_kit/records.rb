# frozen_string_literal: true

module JsonApiKit
  class Records
    include Enumerable

    class Page
      attr_reader :records, :cursor

      def initialize(records, cursor)
        @records = records
        @cursor = cursor
      end
    end

    delegate :each, :size, :empty?, :to_ary, to: :records

    def initialize(records)
      @records = records
    end

    def page(size) = Page.new(self.class.new(records.first(size)), cursor_after(size))

    def fetch_all(rows) = self.class.new(rows.map { by_record.fetch(it) })

    private

    attr_reader :records

    def by_record = @by_record ||= records.index_by(&:record)

    def cursor_after(size)
      return if records.size <= size
      records[size - 1].cursor
    end
  end
end
