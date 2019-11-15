# frozen_string_literal: true

class ReviewableQueuedPostSerializer < ReviewableSerializer

  attributes :reply_to_post_number

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
    :raw_email
  )

  def reply_to_post_number
    object.payload['reply_to_post_number'].to_i
  end

  def include_reply_to_post_number?
    object.payload.present? && object.payload['reply_to_post_number'].present?
  end

end
