# frozen_string_literal: true

require_relative 'post_item_excerpt'

class UserBookmarkBaseSerializer < ApplicationSerializer
  include PostItemExcerpt

  attributes :id,
             :created_at,
             :updated_at,
             :name,
             :reminder_at,
             :pinned,
             :title,
             :fancy_title,
             :bookmarkable_id,
             :bookmarkable_type,
             :bookmarkable_user_username,
             :bookmarkable_user_avatar_template,
             :bookmarkable_user_name,
             :bookmarkable_url

  def title
    object.name
  end

  def fancy_title
    object.name
  end

  def cooked
    "test cookie"
  end

  def bookmarkable_user_username
    bookmarkable_user.username
  end

  def bookmarkable_user_avatar_template
    bookmarkable_user.avatar_template
  end

  def bookmarkable_user_name
    bookmarkable_user.name
  end

  def bookmarkable_url
    # we get the topic URL using topic-link for topic + post bookmarks,
    # this is only for other bookmarkables to define their own urls
  end
end
