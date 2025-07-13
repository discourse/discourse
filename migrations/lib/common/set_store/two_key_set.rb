# frozen_string_literal: true

module Migrations::SetStore
  class TwoKeySet
    include Interface

    def initialize
      @store = Hash.new { |h1, k1| h1[k1] = Hash.new { |h2, k2| h2[k2] = Set.new } }
    end

    def add(key1, key2, value)
      @store[key1][key2].add(value)
      self
    end

    def add?(key1, key2, value)
      !!@store[key1][key2].add?(value)
    end

    def include?(key1, key2, value)
      h1 = @store[key1] or return false
      h2 = h1[key2] or return false
      h2.include?(value)
    end

    def bulk_add(records)
      records.each { |record| @store[record[0]][record[1]].add(record[2]) }
      nil
    end
  end
end
