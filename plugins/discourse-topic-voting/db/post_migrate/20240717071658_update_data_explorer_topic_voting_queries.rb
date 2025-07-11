# frozen_string_literal: true

class UpdateDataExplorerTopicVotingQueries < ActiveRecord::Migration[7.0]
  def up
    has_data_explorer_queries = DB.query_single(<<~SQL).first
      SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_name = 'data_explorer_queries'
      );
    SQL

    DB.exec(<<~SQL) if has_data_explorer_queries
        UPDATE data_explorer_queries
        SET sql = REPLACE(
          REPLACE(sql, 'discourse_voting_topic_vote_count', 'topic_voting_topic_vote_count'),
          'discourse_voting_votes', 'topic_voting_votes'
        )
        WHERE sql LIKE '%discourse_voting_topic_vote_count%'
           OR sql LIKE '%discourse_voting_votes%';
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
