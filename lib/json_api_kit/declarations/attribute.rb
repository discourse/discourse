# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Attribute
      attr_reader :name

      delegate :readable_by?, :readable_for?, to: :readable

      def initialize(name, readable: Readable::ALWAYS, columns: nil, &value)
        @name = name.to_s
        @readable = Readable.for(readable)
        @columns = columns
        @value = value
      end

      def value_for(record)
        return value.call(record) if value
        record.public_send(name)
      end

      # `nil` stands for a column it can't name, which selects them all.
      def columns_for(schema)
        return [nil] if readable.per_record?
        return columns if columns
        return [nil] if value
        [schema.column(name)]
      end

      private

      attr_reader :readable, :columns, :value
    end
  end
end
