# frozen_string_literal: true

module JsonApiKit
  class Sideloads
    class << self
      def for(relationships, paths:, rows:, request:, schema:)
        new(
          relationships.map do
            Sideload.new(it, paths: paths.next_for(it.name), rows:, request:, schema:)
          end,
        )
      end
    end

    def initialize(sideloads)
      @sideloads = sideloads
    end

    def linkage_for(row) = sideloads.to_h { [it.name, it.linkage_for(row)] }

    private

    attr_reader :sideloads
  end
end
