# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      class Association
        def initialize(scope:, owner_records:, owner_key:, related_key:)
          @scope = scope
          @owner_records = owner_records
          @owner_key = owner_key.to_sym
          @related_key = related_key.to_sym
        end

        def related_scope = scope.where(related_key => owner_values)

        def to_scoping = Scoping::PerOwner.new(related_scope, owner_key: related_key)

        def pair(related_records)
          pair_groups(GroupedRecords.new(related_records.group_by { related_value(it) }))
        end

        private

        attr_reader :scope, :owner_records, :owner_key, :related_key

        def pair_groups(groups)
          owner_records.to_h { [it, groups.for(owner_value(it))] }
        end

        def owner_values = owner_records.filter_map { owner_value(it) }.uniq

        def owner_value(record) = record.public_send(owner_key)

        def related_value(record) = record.public_send(related_key)
      end
    end
  end
end
