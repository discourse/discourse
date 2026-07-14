# frozen_string_literal: true

class NestedTopic < ActiveRecord::Base
  self.ignored_columns = ["pinned_post_number"]

  MAX_PINNED_POSTS = 10

  belongs_to :topic, -> { with_deleted }

  validates :topic_id, presence: true, uniqueness: true

  def pin_limit_reached?
    pinned_post_ids.length >= MAX_PINNED_POSTS
  end

  def toggle_pin(post_id)
    if pinned_post_ids.include?(post_id)
      self.pinned_post_ids = pinned_post_ids - [post_id]
    else
      self.pinned_post_ids = pinned_post_ids + [post_id]
    end
    save!
  end
end

# == Schema Information
#
# Table name: nested_topics
#
#  id              :bigint           not null, primary key
#  pinned_post_ids :bigint           default([]), not null, is an Array
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  topic_id        :bigint           not null
#
# Indexes
#
#  index_nested_topics_on_topic_id  (topic_id) UNIQUE
#
