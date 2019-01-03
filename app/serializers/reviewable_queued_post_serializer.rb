class ReviewableQueuedPostSerializer < ReviewableSerializer

  payload_attributes(
    :raw,
    :title,
    :archetype,
    :category,
    :visible,
    :is_warning,
    :first_post_checks,
    :featured_link,
    :reply_to_post_number,
    :is_poll,
    :typing_duration_msecs,
    :composer_open_duration_msecs,
    :tags
  )

end
