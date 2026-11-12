# frozen_string_literal: true

class RemoveEnableTopicVotingBadgesSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'enable_topic_voting_badges'"
    execute "DELETE FROM site_setting_groups WHERE name = 'enable_topic_voting_badges'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
