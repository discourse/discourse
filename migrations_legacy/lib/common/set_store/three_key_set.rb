# frozen_string_literal: true

module Migrations::SetStore
  class ThreeKeySet
    include Interface

    def initialize
      @store = {}
    end

    def add(key1, key2, key3, value)
      h1 = @store[key1] ||= {}
      h2 = h1[key2] ||= {}
      set = h2[key3] ||= Set.new
      set.add(value)
      self
    end

    def add?(key1, key2, key3, value)
      h1 = @store[key1] ||= {}
      h2 = h1[key2] ||= {}
      set = h2[key3] ||= Set.new
      !!set.add?(value)
    end

    def include?(key1, key2, key3, value)
      h1 = @store[key1] or return false
      h2 = h1[key2] or return false
      set = h2[key3] or return false
      set.include?(value)
    end

    def bulk_add(records)
      current_key1 = :__uninitialized__
      current_key2 = :__uninitialized__
      current_key3 = :__uninitialized__
      current_h1 = nil
      current_h2 = nil
      current_set = nil

      records.each do |record|
        key1, key2, key3, value = record

        if key1 != current_key1
          current_key1 = key1
          current_h1 = @store[key1] ||= {}
          current_key2 = key2
          current_h2 = current_h1[key2] ||= {}
          current_key3 = key3
          current_set = current_h2[key3] ||= Set.new
        elsif key2 != current_key2
          current_key2 = key2
          current_h2 = current_h1[key2] ||= {}
          current_key3 = key3
          current_set = current_h2[key3] ||= Set.new
        elsif key3 != current_key3
          current_key3 = key3
          current_set = current_h2[key3] ||= Set.new
        end

        current_set.add(value)
      end
      nil
    end

    def empty?
      @store.empty?
    end
  end
end
