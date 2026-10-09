# frozen_string_literal: true

module JsonApiKit
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
      related_by_key = related_records.group_by { related_value(it) }
      positions = related_by_key.keys.each_with_index.to_h
      related_keys.transform_values do |keys|
        keys.sort_by { positions.fetch(it, 0) }.flat_map { related_by_key.fetch(it, []) }
      end
    end

    private

    attr_reader :scope, :owner_records, :owner_key, :related_key

    def related_keys = owner_records.to_h { [it, [owner_value(it)]] }

    def owner_values = owner_records.filter_map { owner_value(it) }.uniq

    def owner_value(record) = record.public_send(owner_key)

    def related_value(record) = record.public_send(related_key)
  end
end
