# frozen_string_literal: true

class BackupDraftTopic < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic
end

# == Schema Information
#
# Table name: backup_draft_topics
#
#  id         :bigint           not null, primary key
#  user_id    :integer          not null
#  topic_id   :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_backup_draft_topics_on_topic_id  (topic_id) UNIQUE
#  index_backup_draft_topics_on_user_id   (user_id) UNIQUE
#
