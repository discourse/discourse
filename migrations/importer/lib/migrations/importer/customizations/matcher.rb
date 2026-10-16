# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      # Finds imported categories and groups again although their ids differ
      # between test migrations. Strategies are tried in order; export records
      # the keys of all of them so apply can use whichever works on the target.
      class Matcher
        Match = Data.define(:id, :strategy)

        def self.build(mappings_db_path: nil)
          strategies = []
          if mappings_db_path.present?
            strategies << Strategies::Mappings.new(MappingsDB.new(mappings_db_path))
          end
          strategies << Strategies::ImportId.new
          strategies << Strategies::NaturalKey.new
          new(strategies)
        end

        def initialize(strategies)
          @strategies = strategies
        end

        # @param kind [Symbol] :category or :group
        def keys_for(kind, record)
          @strategies.each_with_object({}) do |strategy, keys|
            keys.merge!(strategy.keys_for(kind, record).compact)
          end
        end

        # @yieldparam id [Integer] candidate id; return false to try the next strategy
        # @return [Match, nil]
        def resolve(kind, keys)
          keys = (keys || {}).transform_keys(&:to_s)

          @strategies.each do |strategy|
            id = strategy.find_id(kind, keys)
            next if id.nil?
            next if block_given? && !yield(id)

            return Match.new(id:, strategy: strategy.name)
          end

          nil
        end

        def close
          @strategies.each { |strategy| strategy.close if strategy.respond_to?(:close) }
        end
      end
    end
  end
end
