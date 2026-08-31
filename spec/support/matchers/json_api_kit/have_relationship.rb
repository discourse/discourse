# frozen_string_literal: true

require_relative "matcher"

module JsonApiKitMatchers
  class HaveRelationship < Matcher
    KINDS = {
      one: JsonApiKit::Declarations::Relationship::ToOne,
      many: JsonApiKit::Declarations::Relationship::ToMany,
    }.freeze

    attr_reader :name, :kind

    def initialize(name, kind)
      @name = name.to_s
      @kind = kind
    end

    def satisfied?
      relationship && right_kind? && association_table && tables_agree?
    end

    def description
      "have #{kind} #{name}"
    end

    def failure_message
      unless relationship
        return "Expected #{resource} to #{description}, but it declares #{declared_names}."
      end
      return "Expected #{resource} to #{description}, but it has #{other_kind}." unless right_kind?
      return missing_association_message unless association_table
      table_mismatch_message
    end

    private

    def relationship = @relationship ||= resource.relationships.pick([name]).first

    def right_kind? = relationship.instance_of?(KINDS.fetch(kind))

    def other_kind = kind == :one ? "many" : "one"

    def declared_names = in_words(resource.relationships.names)

    def association_table
      @association_table ||= resource.schema.table_of(name.to_sym)
    rescue JsonApiKit::Schema::MissingAssociation => error
      @missing = error.message
      nil
    end

    def related_table = relationship.resource.model.table_name

    def tables_agree? = association_table == related_table

    def missing_association_message
      "Expected #{resource} to #{description}, but #{resource.model} has no association " \
        "named #{name}."
    end

    def table_mismatch_message
      "Expected #{resource} to #{description}, but the association reads #{association_table} " \
        "and #{relationship.resource} reads #{related_table}."
    end
  end
end
