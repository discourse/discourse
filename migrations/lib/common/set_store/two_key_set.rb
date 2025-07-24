# frozen_string_literal: true

module Migrations::SetStore
  class TwoKeySet
    include Interface

    def initialize
      @store = {}
    end

    def add(key1, key2, value)
      h1 = @store[key1] ||= {}
      set = h1[key2] ||= Set.new
      set.add(value)
      self
    end

    def add?(key1, key2, value)
      h1 = @store[key1] ||= {}
      set = h1[key2] ||= Set.new
      !!set.add?(value)
    end

    def include?(key1, key2, value)
      h1 = @store[key1] or return false
      set = h1[key2] or return false
      set.include?(value)
    end

    def bulk_add(records)
      current_key1 = nil
      current_key2 = nil
      current_h1 = nil
      current_set = nil

      records.each do |record|
        key1, key2, value = record

        if key1 != current_key1
          current_key1 = key1
          current_h1 = @store[key1] ||= {}
          current_key2 = key2
          current_set = current_h1[key2] ||= Set.new
        elsif key2 != current_key2
          current_key2 = key2
          current_set = current_h1[key2] ||= Set.new
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
