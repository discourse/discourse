# frozen_string_literal: true

class WebHookTopicViewSerializer < TopicViewSerializer
  attributes :created_by,
             :last_poster

  %i{
    post_stream
    timeline_lookup
    pm_with_non_human_user
    draft
    draft_key
    draft_sequence
    message_bus_last_id
    suggested_topics
    has_summary
    actions_summary
    current_post_number
    chunk_size
    topic_timer
    private_topic_timer
    details
    image_url
  }.each do |attr|
    define_method("include_#{attr}?") do
      false
    end
  end

  def include_show_read_indicator?
    false
  end

  def created_by
    BasicUserSerializer.new(object.topic.user, scope: scope, root: false)
  end

  def last_poster
    BasicUserSerializer.new(object.topic.last_poster, scope: scope, root: false)
  end
end
