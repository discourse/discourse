# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Sort
      class Related < Sort
        private

        def sql_for(schema) = sql || "#{schema.table_of(association)}.#{related_column}"

        def joins = super.presence || association

        def nulls = super || :last

        def association = parts.first.to_sym

        def related_column = parts.last

        def parts = @parts ||= name.split(SEPARATOR)
      end
    end
  end
end
