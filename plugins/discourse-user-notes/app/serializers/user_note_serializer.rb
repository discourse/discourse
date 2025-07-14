# frozen_string_literal: true

class ::UserNoteSerializer < ApplicationSerializer
  attributes(
    :id,
    :user_id,
    :raw,
    :created_by,
    :created_at,
    :can_delete,
    :post_id,
    :post_url,
    :post_title,
  )

  def id
    object[:id]
  end

  def user_id
    object[:user_id]
  end

  def raw
    object[:raw]
  end

  def created_by
    BasicUserSerializer.new(object[:created_by], scope: scope, root: false)
  end

  def created_at
    object[:created_at]
  end

  def can_delete
    scope.can_delete_user_notes?
  end

  def post_id
    object[:post_id]
  end

  def post_url
    url = object[:post].try(:url)

    # In case the topic is deleted
    url = "/t/#{object[:post].topic_id}/#{object[:post].post_number}" if url == "/404"

    "#{Discourse.base_path}#{url}"
  end

  def post_title
    object[:post].try(:title)
  end

  def topic_id
    object[:topic_id]
  end
end
