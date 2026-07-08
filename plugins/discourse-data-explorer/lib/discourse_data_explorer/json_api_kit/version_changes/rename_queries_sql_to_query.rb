# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    module VersionChanges
      # Pairs with the 2026-06-15 wire rename in QuerySerializer/Query::Create
      # (docs/versioning-design.md, §1). Not applied to traffic until the pipeline
      # lands (design doc §2, increments ②–③).
      class RenameQueriesSqlToQuery < VersionChange
        version "2026-06-15"
        description "The `sql` attribute of the queries resource is renamed to `query`."

        resource :queries do
          # Key-guarded: an unguarded delete-based rename would fabricate a nil
          # attribute when the key is absent (e.g. excluded by a sparse fieldset).
          up do |resource|
            attributes = resource[:attributes]
            attributes[:query] = attributes.delete(:sql) if attributes.key?(:sql)
          end
          down do |resource|
            attributes = resource[:attributes]
            attributes[:sql] = attributes.delete(:query) if attributes.key?(:query)
          end
        end
      end
    end
  end
end
