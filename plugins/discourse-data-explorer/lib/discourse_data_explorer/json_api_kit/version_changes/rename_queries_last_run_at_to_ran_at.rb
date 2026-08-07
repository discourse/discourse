# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    module VersionChanges
      # Pairs with the 2026-07-08 wire rename in QueryResource. The `ran_at`
      # sort key is attribute-derived (`sort :ran_at, column: :last_run_at`), so
      # old clients' `sort=last_run_at` follows this rename automatically — no
      # extra declaration needed.
      class RenameQueriesLastRunAtToRanAt < VersionChange
        version "2026-07-08"
        description "The `last_run_at` attribute of the queries resource is renamed to `ran_at`."

        resource :queries do
          renamed_attribute from: :last_run_at, to: :ran_at
        end
      end
    end
  end
end
