# frozen_string_literal: true

module JsonApiKit
  class Schema
    attr_reader :model

    def initialize(model)
      @model = model
    end

    def primary_key = model.primary_key.to_sym

    def column(name)
      return unless columns.key?(name.to_s)
      name.to_sym
    end

    def nullable?(name)
      column = columns[name.to_s]
      return true unless column
      column.null
    end

    def owner_key(name)
      reflection = model.reflect_on_association(name)
      return primary_key if reflection.through_reflection?
      keys_of(reflection).fetch(:owner_key).to_sym
    end

    def association(name, owner_records)
      reflection = model.reflect_on_association(name)
      return key_in_another_table(reflection, owner_records) if reflection.through_reflection?
      Association.new(scope: related_scope(reflection), owner_records:, **keys_of(reflection))
    end

    private

    def columns = model.columns_hash

    def keys_of(reflection)
      return keys_on_owner_row(reflection) if reflection.belongs_to?
      keys_on_related_row(reflection)
    end

    def keys_on_owner_row(reflection)
      { owner_key: reflection.foreign_key, related_key: reflection.association_primary_key }
    end

    def keys_on_related_row(reflection)
      { owner_key: reflection.active_record_primary_key, related_key: reflection.foreign_key }
    end

    def key_in_another_table(reflection, owner_records)
      Association::Through.new(
        scope: related_scope(reflection),
        owner_records:,
        owner_key: primary_key,
        related_key: reflection.association_primary_key,
        join_scope: reflection.through_reflection.klass.all,
        join_owner_key: reflection.through_reflection.foreign_key,
        join_related_key: reflection.source_reflection.foreign_key,
      )
    end

    def related_scope(reflection)
      rows = reflection.klass.all
      return rows unless reflection.scope
      rows.merge(reflection.scope)
    end
  end
end
