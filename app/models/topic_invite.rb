# frozen_string_literal: true

class TopicInvite < ActiveRecord::Base
  belongs_to :topic
  belongs_to :invite

  validates :topic_id, presence: true
  validates :invite_id, presence: true

  validates :topic_id, uniqueness: { scope: :invite_id }
end

# == Schema Information
#
# Table name: topic_invites
#
#  id         :integer          not null, primary key
#  topic_id   :integer          not null
#  invite_id  :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_topic_invites_on_invite_id               (invite_id)
#  index_topic_invites_on_topic_id_and_invite_id  (topic_id,invite_id) UNIQUE
#
