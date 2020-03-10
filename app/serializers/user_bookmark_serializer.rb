# frozen_string_literal: true

require_relative 'post_item_excerpt'

class UserBookmarkSerializer < ApplicationSerializer
  include PostItemExcerpt
  include TopicTagsMixin

  attributes :id,
             :created_at,
             :topic_id,
             :bookmark_post_number,
             :post_id,
             :bookmark_name,
             :bookmark_reminder_at,
             :title,
             :deleted,
             :hidden,
             :category_id,
             :closed,
             :archived,
             :archetype,
             :highest_post_number,
             :bumped_at,
             :slug,
             :username

  def closed
    object.topic_closed
  end

  def archived
    object.topic_archived
  end
end
