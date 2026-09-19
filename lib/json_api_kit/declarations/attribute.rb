# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Attribute
      attr_reader :name

      delegate :readable_by?, :readable_for?, to: :readable

      def initialize(name, readable: Readable::ALWAYS, &value)
        @name = name.to_s
        @readable = Readable.for(readable)
        @value = value
      end

      def value_for(record)
        return value.call(record) if value
        record.public_send(name)
      end

      def column_for(schema)
        return if value || readable.per_record?
        schema.column(name)
      end

      private

      attr_reader :readable, :value
    end
  end
end
