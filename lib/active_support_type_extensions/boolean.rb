# frozen_string_literal: true

module ActiveSupportTypeExtensions
  # Casts like ActiveModel's boolean, which turns any unrecognised value into
  # `true`. When strict, `Service::ContractBase` rejects such values instead.
  class Boolean < ActiveModel::Type::Boolean
    ACCEPTED_VALUES = Set[nil, "", true, false, 1, 0, "1", "0", "true", "false", "on", "off"].freeze

    attr_reader :strict

    def initialize(strict: true, **)
      super(**)
      @strict = strict
    end

    def valid_input?(value)
      !strict || ACCEPTED_VALUES.include?(value)
    end
  end
end
