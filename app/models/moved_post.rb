# frozen_string_literal: true

class MovedPost < ActiveRecord::Base
  belongs_to :old_topic, class_name: "Topic", foreign_key: :old_topic_id
  belongs_to :old_post, class_name: "Post", foreign_key: :old_post_id

  belongs_to :new_topic, class_name: "Topic", foreign_key: :new_topic_id
  belongs_to :new_post, class_name: "Post", foreign_key: :new_post_id
end
