# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class PermalinkNormalizations < Base::Step
        attr_accessor :source_db

        def execute
          normalizations = @source_db.query_value <<~SQL
            SELECT value
            FROM site_settings
            WHERE name = 'permalink_normalizations'
          SQL

          return if normalizations.blank?

          normalizations
            .split("|")
            .each { |normalization| IntermediateDB::PermalinkNormalization.create(normalization:) }
        end
      end
    end
  end
end
