# frozen_string_literal: true

module Migrations
  # Module that adds enumeration functionality to modules that extend it.
  # When extended, adds methods for checking and retrieving enum values.
  #
  # @example
  #   module MyEnum
  #     extend ::Migrations::Enum
  #
  #     FIRST = 0
  #     SECOND = 1
  #   end
  #
  # @!method valid?(value)
  #   Checks if the provided value is a valid enum value
  #   @param value [Integer, String] The value to check
  #   @return [Boolean] true if the value is included in the enum values
  #
  # @!method values
  #   Returns all values defined in the enum
  #   @return [Array<Integer, String>] Array of all enum values
  module Enum
    def self.extended(base)
      TracePoint
        .new(:end) do |tp|
          if tp.self == base
            enum_values =
              base.constants.map { |c| base.const_get(c) }.select { |v| !v.is_a?(Module) }.freeze

            values = base.const_set(:ALL_ENUM_VALUES__, enum_values)
            base.private_constant :ALL_ENUM_VALUES__

            base.define_singleton_method(:valid?) { |value| values.include?(value) }
            base.define_singleton_method(:values) { values }

            tp.disable
          end
        end
        .enable
    end
  end
end
