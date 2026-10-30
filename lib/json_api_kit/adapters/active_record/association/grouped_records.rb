# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      class Association
        class GroupedRecords
          def initialize(groups)
            @groups = groups
          end

          def for(key) = groups.fetch(key, []).dup

          def for_keys(keys)
            keys.sort_by { positions.fetch(it, 0) }.flat_map { groups.fetch(it, []) }
          end

          private

          attr_reader :groups

          def positions = @positions ||= groups.keys.each_with_index.to_h
        end
      end
    end
  end
end
