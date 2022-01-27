# frozen_string_literal: true

class RemoveCanonicalEmailFromUserEmails < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      ALTER TABLE user_emails
      DROP COLUMN IF EXISTS canonical_email
    SQL
  end
  def down
    # nothing to do, we already nuke the migrations
  end
end
