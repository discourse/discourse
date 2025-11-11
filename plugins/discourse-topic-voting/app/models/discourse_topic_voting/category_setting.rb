# frozen_string_literal: true

module DiscourseTopicVoting
  class CategorySetting < ActiveRecord::Base
    self.table_name = "topic_voting_category_settings"

    belongs_to :category, inverse_of: :discourse_topic_voting_category_setting

    before_create :unarchive_votes
    before_destroy :archive_votes
    after_save :reset_voting_cache

    def unarchive_votes
      DB.exec(<<~SQL, { category_id: self.category_id })
        UPDATE topic_voting_votes
        SET archive=false
        FROM topics
        WHERE topics.category_id = :category_id
        AND topics.deleted_at is NULL
        AND NOT topics.closed
        AND NOT topics.archived
        AND topic_voting_votes.topic_id = topics.id
      SQL
    end

    def archive_votes
      DB.exec(<<~SQL, { category_id: self.category_id })
        UPDATE topic_voting_votes
        SET archive=true
        FROM topics
        WHERE topics.category_id = :category_id
        AND topic_voting_votes.topic_id = topics.id
      SQL
    end

    def reset_voting_cache
      ::Category.reset_voting_cache
    end
  end
end

# == Schema Information
#
# Table name: topic_voting_category_settings
#
#  id          :bigint           not null, primary key
#  category_id :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  topic_voting_category_settings_category_id_idx  (category_id) UNIQUE
#
