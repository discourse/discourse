# frozen_string_literal: true

module JsonApiKit
  class Document
    class Contents
      def initialize(primary_records, related_records)
        @primary_records = primary_records
        @related_records = related_records
      end

      def primary = @primary ||= identities.map { merged_records.fetch(it) }

      def related = @related ||= merged_records.except(*identities).values

      private

      attr_reader :primary_records, :related_records

      def identities = @identities ||= primary_records.map(&:identity)

      def merged_records
        @merged_records ||=
          [*primary_records, *related_records].group_by(&:identity)
            .transform_values { it.reduce(:merge) }
      end
    end
  end
end
