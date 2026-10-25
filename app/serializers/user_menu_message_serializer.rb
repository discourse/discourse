# frozen_string_literal: true

class UserMenuMessageSerializer < ApplicationSerializer
  include LocalizedFancyTopicTitleMixin

  attributes :id, :slug, :bumped_at, :highest_post_number, :last_read_post_number, :unread_posts

  has_one :last_poster, serializer: BasicUserSerializer, embed: :objects

  def highest_post_number
    (scope.is_whisperer? && object.highest_staff_post_number) || object.highest_post_number
  end

  def last_read_post_number
    object.user_data.last_read_post_number
  end

  def unread_posts
    Unread.new(object, object.user_data, scope).unread_posts
  end

  def has_user_data
    object.user_data.present?
  end

  alias include_last_read_post_number? has_user_data
  alias include_unread_posts? has_user_data
end
