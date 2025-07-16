# frozen_string_literal: true

module Migrations::SetStore
  class SimpleSet
    include Interface

    def initialize
      @store = Set.new
    end

    def add(value)
      @store.add(value)
      self
    end

    def add?(value)
      !!@store.add?(value)
    end

    def include?(value)
      @store.include?(value)
    end

    def bulk_add(records)
      values = records.lazy.map { |value| value.is_a?(Array) ? value[0] : value }
      @store.merge(values)
      nil
    end
  end
end
