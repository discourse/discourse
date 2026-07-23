# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    module VersionChanges
      # Pairs with the 2026-07-01 shape change in UserResource (string → array,
      # modeled on Cadwyn's ChangeAddressToList — see docs/cadwyn-review.md §2.3).
      # The down converter is deliberately lossy: old clients get the first known
      # username, which is the pre-change meaning.
      class ChangeUsersUsernameToList < VersionChange
        version "2026-07-01"
        description "The `username` attribute of the users resource is replaced by " \
                      "`usernames`, an array of the user's known usernames."

        resource :users do
          renamed_attribute from: :username,
                            to: :usernames,
                            up: ->(username) { [username] },
                            down: ->(usernames) { usernames.first },
                            old_type: :string
        end
      end
    end
  end
end
