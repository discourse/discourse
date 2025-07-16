# frozen_string_literal: true

class DeactivateUnverifiedEmailPatreonAccounts < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      UPDATE users SET active = false
      WHERE users.id IN (
        SELECT user_id FROM user_associated_accounts
        WHERE provider_name = 'patreon'
        AND extra -> 'raw_info' -> 'data' -> 'attributes' ->> 'is_email_verified' = 'false'
      )
    SQL
  end

  def down
    # noop
  end
end
