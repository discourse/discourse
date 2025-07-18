# frozen_string_literal: true

module Migrations::SetStore
  class KeyValueSet
    include Interface

    def initialize
      @store = Hash.new { |h, k| h[k] = Set.new }
    end

    def add(key, value)
      @store[key].add(value)
      self
    end

    def add?(key, value)
      !!@store[key].add?(value)
    end

    def include?(key, value)
      h = @store[key] or return false
      h.include?(value)
    end

    def bulk_add(records)
      records.each { |record| @store[record[0]].add(record[1]) }
      nil
    end
  end
end
