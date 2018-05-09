require_dependency 'pinned_check'

class WebHookTopicViewSerializer < TopicViewSerializer

  %i{
    post_stream
    timeline_lookup
    pm_with_non_human_user
    draft
    draft_key
    draft_sequence
    message_bus_last_id
  }.each do |attr|
    define_method("include_#{attr}?") do
      false
    end
  end
end
