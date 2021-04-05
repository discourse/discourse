# frozen_string_literal: true

class TopicPostCountSerializer < BasicUserSerializer

  attributes :post_count, :primary_group_name,
             :primary_group_flair_url, :primary_group_flair_color, :primary_group_flair_bg_color,
             :admin, :moderator, :trust_level,

  def id
    object[:user].id
  end

  def username
    object[:user].username
  end

  def post_count
    object[:post_count]
  end

  def primary_group_name
    return nil unless object[:user].primary_group_id
    object[:user]&.primary_group&.name
  end

  def primary_group_flair_url
    object[:user]&.primary_group&.flair_url
  end

  def primary_group_flair_bg_color
    object[:user]&.primary_group&.flair_bg_color
  end

  def primary_group_flair_color
    object[:user]&.primary_group&.flair_color
  end

  def include_admin?
    object[:user].admin
  end

  def admin
    true
  end

  def include_moderator?
    object[:user].moderator
  end

  def moderator
    true
  end

  def trust_level
    object[:user].trust_level
  end

end
