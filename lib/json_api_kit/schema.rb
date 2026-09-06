# frozen_string_literal: true

module JsonApiKit
  class Schema
    MissingAssociation = Class.new(StandardError)

    attr_reader :model

    delegate :reflect_on_association, to: :model, private: true

    def initialize(model)
      @model = model
    end

    def table_of(association)
      reflect_on_association(association).try { it.klass.table_name } or
        raise MissingAssociation, "#{model}: there is no association named #{association}"
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

    def owner_key(name) = reflection_for(name).owner_key

    def association(name, owner_records) = reflection_for(name).association(owner_records)

    private

    def columns = model.columns_hash

    def reflection_for(name) = Reflection.for(reflect_on_association(name))
  end
end
