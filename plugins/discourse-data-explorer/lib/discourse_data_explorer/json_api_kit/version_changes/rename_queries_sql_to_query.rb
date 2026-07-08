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
          up { |resource| resource[:attributes][:query] = resource[:attributes].delete(:sql) }
          down { |resource| resource[:attributes][:sql] = resource[:attributes].delete(:query) }
        end
      end
    end
  end
end
