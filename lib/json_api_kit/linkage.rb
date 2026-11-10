# frozen_string_literal: true

module JsonApiKit
  class Linkage
    attr_reader :records, :filtering

    def initialize(records, filtering: {})
      @records = records
      @filtering = filtering
    end

    def pages = {}

    def filtered_like?(other) = filtering == other.filtering
  end
end
