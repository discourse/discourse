# frozen_string_literal: true

module Migrations::SetStore
  class ThreeKeySet
    include Interface

    def initialize
      @store =
        Hash.new do |h1, k1|
          h1[k1] = Hash.new { |h2, k2| h2[k2] = Hash.new { |h3, k3| h3[k3] = Set.new } }
        end
    end

    def add(key1, key2, key3, value)
      @store[key1][key2][key3].add(value)
      self
    end

    def add?(key1, key2, key3, value)
      !!@store[key1][key2][key3].add?(value)
    end

    def include?(key1, key2, key3, value)
      h1 = @store[key1] or return false
      h2 = h1[key2] or return false
      h3 = h2[key3] or return false
      h3.include?(value)
    end

    def bulk_add(records)
      records.each { |record| @store[record[0]][record[1]][record[2]].add(record[3]) }
      nil
    end
  end
end
