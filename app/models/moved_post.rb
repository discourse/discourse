# frozen_string_literal: true

class MovedPost < ActiveRecord::Base
  belongs_to :old_topic, class_name: "Topic", foreign_key: :old_topic_id
  belongs_to :old_post, class_name: "Post", foreign_key: :old_post_id

  belongs_to :new_topic, class_name: "Topic", foreign_key: :new_topic_id
  belongs_to :new_post, class_name: "Post", foreign_key: :new_post_id
end

# == Schema Information
#
# Table name: moved_posts
#
#  id                :bigint           not null, primary key
#  old_topic_id      :bigint
#  old_post_id       :bigint
#  old_post_number   :bigint
#  new_topic_id      :bigint           not null
#  new_topic_title   :string           not null
#  new_post_id       :bigint           not null
#  new_post_number   :bigint           not null
#  created_new_topic :boolean          default(FALSE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_moved_posts_on_new_post_id      (new_post_id)
#  index_moved_posts_on_new_topic_id     (new_topic_id)
#  index_moved_posts_on_old_post_id      (old_post_id)
#  index_moved_posts_on_old_post_number  (old_post_number)
#  index_moved_posts_on_old_topic_id     (old_topic_id)
#
