# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    module VersionChanges
      # Pairs with the 2026-06-15 wire rename in QuerySerializer/Query::Create
      # (docs/versioning-design.md, §1).
      class RenameQueriesSqlToQuery < VersionChange
        version "2026-06-15"
        description "The `sql` attribute of the queries resource is renamed to `query`."

        resource :queries do
          renamed_attribute from: :sql, to: :query
        end
      end
    end
  end
end
