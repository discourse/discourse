# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # The spike API's v-day zero (docs/versioning-design.md, §1).
    INITIAL_API_VERSION = "2026-05-01"

    class << self
      # The API's version registry — every VersionChange is registered here.
      # Memoized for the process lifetime; in dev a code reload can leave stale
      # change classes behind (restart to refresh). Spike trade-off.
      def api_versions
        @api_versions ||=
          VersionRegistry
            .new(initial_version: INITIAL_API_VERSION)
            .tap do |registry|
              registry.register(VersionChanges::RenameQueriesSqlToQuery)
              registry.register(VersionChanges::ChangeUsersUsernameToList)
              registry.register(VersionChanges::RenameQueriesLastRunAtToRanAt)
              registry.register(VersionChanges::RenameQueriesSearchFilterToQ)
              registry.register(VersionChanges::RenameQueriesUsernameSortToUserUsername)
            end
      end
    end
  end
end
