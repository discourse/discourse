# frozen_string_literal: true

module Migrations
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
