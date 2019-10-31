# frozen_string_literal: true

class TopicViewWordpressSerializer < ApplicationSerializer

  # These attributes will be delegated to the topic
  attributes :id,
             :posts_count,
             :filtered_posts_count,
             :posts

  has_many :participants, serializer: UserWordpressSerializer, embed: :objects
  has_many :posts, serializer: PostWordpressSerializer, embed: :objects

  def id
    object.topic.id
  end

  def posts_count
    object.topic.posts_count
  end

  def filtered_posts_count
    object.filtered_post_ids.size
  end

  def participants
    object.participants.values
  end

  def posts
    object.posts
  end

end
