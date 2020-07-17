# frozen_string_literal: true

class SearchTopicListItemSerializer < ListableTopicSerializer
  include TopicTagsMixin

  attributes :category_id

  %i{
    image_url
    thumbnails
    title
    created_at
    last_posted_at
    bumped_at
    bumped
    highest_post_number
    reply_count
    unseen
  }.each do |attr|
    define_method("include_#{attr}?") do
      false
    end
  end
end
