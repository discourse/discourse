# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    module VersionChanges
      # Pairs with the 2026-07-01 shape change in UserSerializer (string → array,
      # modeled on Cadwyn's ChangeAddressToList — see docs/cadwyn-review.md §2.3).
      # The down direction is deliberately lossy: old clients get the first known
      # username, which is the pre-change meaning.
      class ChangeUsersUsernameToList < VersionChange
        version "2026-07-01"
        description "The `username` attribute of the users resource is replaced by " \
                      "`usernames`, an array of the user's known usernames."

        resource :users do
          up do |resource|
            attributes = resource[:attributes]
            attributes[:usernames] = [attributes.delete(:username)] if attributes.key?(:username)
          end
          down do |resource|
            attributes = resource[:attributes]
            attributes[:username] = attributes.delete(:usernames).first if attributes.key?(
              :usernames,
            )
          end
        end
      end
    end
  end
end
