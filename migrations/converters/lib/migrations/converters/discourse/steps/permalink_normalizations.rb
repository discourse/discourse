# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class PermalinkNormalizations < Conversion::Step
        source do
          def max_progress
            normalizations.size
          end

          def items
            normalizations
          end

          private

          def normalizations
            @normalizations ||=
              begin
                value = @source_db.query_value(<<~SQL)
                  SELECT value
                  FROM site_settings
                  WHERE name = 'permalink_normalizations'
                SQL

                value.present? ? value.split("|") : []
              end
          end
        end

        processor do
          def process(item)
            IntermediateDB::PermalinkNormalization.create(normalization: item)
          end
        end
      end
    end
  end
end
