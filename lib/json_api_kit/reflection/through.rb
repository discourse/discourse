# frozen_string_literal: true

module JsonApiKit
  class Reflection
    class Through < Reflection
      delegate :through_reflection, :source_reflection, to: :reflection, private: true

      def owner_key = active_record_primary_key.to_sym

      def association(owner_records)
        Association::Through.new(
          scope:,
          owner_records:,
          owner_key:,
          related_key: association_primary_key,
          join_scope:,
          join_owner_key:,
          join_related_key:,
        )
      end

      private

      def join_scope = through_reflection.klass.all

      def join_owner_key = through_reflection.foreign_key

      def join_related_key = source_reflection.foreign_key
    end
  end
end
