# frozen_string_literal: true

module Chat
  module Action
    module SearchMessage
      # Filters chat messages by username.
      #
      # Supports:
      # - Specific usernames (e.g., "@alice")
      # - Special case "@me" for the current user
      class ApplyUsernameFilter < Service::ActionBase
        # @param [ActiveRecord::Relation] messages The messages relation to filter
        # @param [String] match The username to filter by (without the @ symbol)
        # @param [Guardian] guardian The current user's guardian
        option :messages
        option :username
        option :guardian

        def call
          normalized_username = User.normalize_username(username)
          user_id =
            if normalized_username == "me"
              guardian.user&.id
            else
              User.not_staged.where(username_lower: normalized_username).pick(:id)
            end

          if user_id
            messages.where(user_id: user_id)
          else
            messages.where("1 = 0")
          end
        end
      end
    end
  end
end
