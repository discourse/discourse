# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Attribute
      attr_reader :name, :type

      delegate :readable_by?, :readable_for?, to: :readable

      def initialize(name, type = nil, readable: Readable::ALWAYS, writable: false, &value)
        @name = name.to_s
        @type = type.try { ActiveModel::Type.lookup(it) }
        @writable = writable
        @readable = Readable.for(readable)
        @value = value
        verify!
      end

      def writable? = @writable

      def value_for(record)
        return value.call(record) if value
        record.public_send(name)
      end

      def requires_full_record? = value.present? || readable.per_record?

      private

      attr_reader :readable, :value

      def verify!
        if [true, false].exclude?(@writable)
          raise ArgumentError, "#{name}: writable must be true or false."
        end
        if writable? && type.nil?
          raise ArgumentError, "#{name}: a writable attribute requires a type."
        end
      end
    end
  end
end
