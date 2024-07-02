# frozen_string_literal: true
class UpdateHideProfileAndPresenceForExistingUsers < ActiveRecord::Migration[7.0]
  def change
    reversible do |direction|
      direction.up { execute <<-SQL }
          UPDATE user_options
          SET hide_profile = true,
          hide_presence = true
          WHERE
          hide_profile_and_presence = true
        SQL
      direction.down do
        # Do nothing; rollback means that users can still independently change
        # profile and presence hidden-ness. Their values will be based on the
        # previous hide_both value, which is a good thing (it's the users'
        # previous setting)
      end
    end
  end
end
