# frozen_string_literal: true

module JsonApiKit
  class Reflection
    class << self
      def for(reflection)
        return Through.new(reflection) if reflection.through_reflection?
        new(reflection)
      end
    end

    delegate :belongs_to?,
             :foreign_key,
             :association_primary_key,
             :active_record_primary_key,
             :klass,
             to: :reflection,
             private: true

    def initialize(reflection)
      @reflection = reflection
    end

    def owner_key = keys.fetch(:owner_key).to_sym

    def association(owner_records) = Association.new(scope:, owner_records:, **keys)

    private

    attr_reader :reflection

    def keys
      return keys_on_owner_row if belongs_to?
      keys_on_related_row
    end

    def keys_on_owner_row = { owner_key: foreign_key, related_key: association_primary_key }

    def keys_on_related_row = { owner_key: active_record_primary_key, related_key: foreign_key }

    def scope
      rows = klass.all
      return rows unless reflection.scope
      rows.merge(reflection.scope)
    end
  end
end
