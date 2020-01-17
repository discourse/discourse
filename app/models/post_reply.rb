# frozen_string_literal: true

class PostReply < ActiveRecord::Base
  self.ignored_columns = %w{
    reply_id
  }

  belongs_to :post
  belongs_to :reply, foreign_key: :reply_post_id, class_name: 'Post'

  validates_uniqueness_of :reply_post_id, scope: :post_id
  validate :ensure_same_topic

  private

  def ensure_same_topic
    if post.topic_id != reply.topic_id
      self.errors.add(
        :base,
        I18n.t("activerecord.errors.models.post_reply.base.different_topic")
      )
    end
  end
end

# == Schema Information
#
# Table name: post_replies
#
#  post_id       :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  reply_post_id :integer
#
# Indexes
#
#  index_post_replies_on_post_id_and_reply_post_id  (post_id,reply_post_id) UNIQUE
#  index_post_replies_on_reply_post_id              (reply_post_id)
#
