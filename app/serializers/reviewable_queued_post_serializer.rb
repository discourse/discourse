# frozen_string_literal: true

class ReviewableQueuedPostSerializer < ReviewableSerializer
  attributes :reply_to_post_number, :fancy_title, :cooked

  payload_attributes(
    :raw,
    :title,
    :archetype,
    :category,
    :visible,
    :is_warning,
    :first_post_checks,
    :featured_link,
    :is_poll,
    :typing_duration_msecs,
    :composer_open_duration_msecs,
    :tags,
    :via_email,
    :raw_email,
  )

  def fancy_title
    ERB::Util.html_escape(object.payload["title"]) if object.payload&.[]("title")
  end

  def cooked
    PrettyText.cook(object.payload["raw"]) if object.payload&.[]("raw")
  end

  def reply_to_post_number
    object.payload["reply_to_post_number"].to_i
  end

  def include_reply_to_post_number?
    object.payload.present? && object.payload["reply_to_post_number"].present?
  end
end
