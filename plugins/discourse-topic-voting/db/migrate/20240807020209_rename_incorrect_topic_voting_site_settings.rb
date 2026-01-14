# frozen_string_literal: true

class RenameIncorrectTopicVotingSiteSettings < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      UPDATE site_settings SET name = 'topic_voting_alert_votes_left'
      WHERE name = 'voting_alert_votes_left' AND
        NOT EXISTS (SELECT 1 FROM site_settings WHERE name = 'topic_voting_alert_votes_left');
    SQL

    execute <<-SQL
      UPDATE site_settings SET name = 'topic_voting_enabled'
      WHERE name = 'voting_enabled' AND
        NOT EXISTS (SELECT 1 FROM site_settings WHERE name = 'topic_voting_enabled');
    SQL

    execute <<-SQL
      UPDATE site_settings SET name = 'topic_voting_show_who_voted'
      WHERE name = 'voting_show_who_voted' AND
        NOT EXISTS (SELECT 1 FROM site_settings WHERE name = 'topic_voting_show_who_voted');
    SQL

    execute <<-SQL
      UPDATE site_settings SET name = 'topic_voting_show_votes_on_profile'
      WHERE name = 'voting_show_votes_on_profile' AND
        NOT EXISTS (SELECT 1 FROM site_settings WHERE name = 'topic_voting_show_votes_on_profile');
    SQL

    execute <<-SQL
      UPDATE site_settings SET name = 'topic_voting_tl0_vote_limit'
      WHERE name = 'voting_tl0_vote_limit' AND
        NOT EXISTS (SELECT 1 FROM site_settings WHERE name = 'topic_voting_tl0_vote_limit');
    SQL

    execute <<-SQL
      UPDATE site_settings SET name = 'topic_voting_tl1_vote_limit'
      WHERE name = 'voting_tl1_vote_limit' AND
        NOT EXISTS (SELECT 1 FROM site_settings WHERE name = 'topic_voting_tl1_vote_limit');
    SQL

    execute <<-SQL
      UPDATE site_settings SET name = 'topic_voting_tl2_vote_limit'
      WHERE name = 'voting_tl2_vote_limit' AND
        NOT EXISTS (SELECT 1 FROM site_settings WHERE name = 'topic_voting_tl2_vote_limit');
    SQL

    execute <<-SQL
      UPDATE site_settings SET name = 'topic_voting_tl3_vote_limit'
      WHERE name = 'voting_tl3_vote_limit' AND
        NOT EXISTS (SELECT 1 FROM site_settings WHERE name = 'topic_voting_tl3_vote_limit');
    SQL

    execute <<-SQL
      UPDATE site_settings SET name = 'topic_voting_tl4_vote_limit'
      WHERE name = 'voting_tl4_vote_limit' AND
        NOT EXISTS (SELECT 1 FROM site_settings WHERE name = 'topic_voting_tl4_vote_limit');
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
