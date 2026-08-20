# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    module VersionChanges
      # Pairs with the 2026-07-08 rename of the queries `username` sort in the
      # controller config, adopting the JSON:API-recommended dotted spelling for
      # relationship-based sort fields. Virtual key (block-backed LEFT JOIN), so
      # the rename takes this explicit declaration. Third change sharing the
      # 2026-07-08 release date — applied in registration order.
      class RenameQueriesUsernameSortToUserUsername < VersionChange
        version "2026-07-08"
        description "The `username` sort of the queries resource is renamed to `user.username`."

        resource :queries do
          renamed_sort from: :username, to: :"user.username"
        end
      end
    end
  end
end
