# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    module VersionChanges
      # Pairs with the 2026-07-08 rename of the queries `search` filter in the
      # controller config. `search` is a VIRTUAL filter (block-backed), so unlike
      # a derived key it does not follow attribute renames — its rename takes this
      # explicit declaration. Same-day as RenameQueriesLastRunAtToRanAt: two
      # changes sharing a release date, applied in registration order.
      class RenameQueriesSearchFilterToQ < VersionChange
        version "2026-07-08"
        description "The `search` filter of the queries resource is renamed to `q`."

        resource :queries do
          renamed_filter from: :search, to: :q
        end
      end
    end
  end
end
