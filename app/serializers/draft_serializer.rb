# frozen_string_literal: true

require_relative 'post_item_excerpt'

class DraftSerializer < ApplicationSerializer
  include PostItemExcerpt

  attributes :created_at,
             :draft_key,
             :sequence,
             :draft_username,
             :avatar_template,
             :data,
             :topic_id,
             :username,
             :username_lower,
             :name,
             :user_id,
             :title,
             :slug,
             :category_id,
             :closed,
             :archetype,
             :archived

  def cooked
    object.parsed_data['reply'] || ""
  end

  def draft_username
    object.user.username
  end

  def avatar_template
    object.user.avatar_template
  end

  def username
    object.display_user&.username
  end

  def username_lower
    object.display_user&.username_lower
  end

  def name
    object.display_user&.name
  end

  def title
    object.topic&.title
  end

  def slug
    object.topic&.slug
  end

  def category_id
    object.topic&.category_id
  end

  def closed
    object.topic&.closed
  end

  def archived
    object.topic&.archived
  end

  def archetype
    object&.topic&.archetype
  end

  def include_slug?
    object.topic&.title&.present?
  end

  def include_closed?
    object.topic&.closed&.present?
  end

  def include_archived?
    object.topic&.archived&.present?
  end

  def include_category_id?
    object.topic&.category_id&.present?
  end

end
