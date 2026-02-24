# frozen_string_literal: true

class RemoveStaleMissingMailgunApiKeyProblemCheckTracker < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM problem_check_trackers WHERE identifier = 'missing_mailgun_api_key'"
  end

  def down
    # no-op: can't restore deleted tracker rows
  end
end
