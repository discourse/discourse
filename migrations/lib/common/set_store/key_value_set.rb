# frozen_string_literal: true

module Migrations::SetStore
  class KeyValueSet
    include Interface

    def initialize
      @store = {}
    end

    def add(key, value)
      (@store[key] ||= Set.new).add(value)
      self
    end

    def add?(key, value)
      !!(@store[key] ||= Set.new).add?(value)
    end

    def include?(key, value)
      set = @store[key] or return false
      set.include?(value)
    end

    def bulk_add(records)
      current_key = :__uninitialized__
      current_set = nil

      records.each do |record|
        key, value = record

        if key != current_key
          current_key = key
          current_set = @store[key] ||= Set.new
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
