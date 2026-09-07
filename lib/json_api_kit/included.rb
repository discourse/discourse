# frozen_string_literal: true

module JsonApiKit
  class Included
    include Enumerable

    class << self
      def for(records) = new(related_to(records))

      private

      def related_to(records)
        related_records = records.flat_map(&:related_records)
        return related_records if related_records.empty?
        related_records + related_to(related_records)
      end
    end

    def initialize(records)
      @records = records
    end

    delegate :empty?, to: :records

    def each(&) = records.each(&)

    private

    attr_reader :records
  end
end
