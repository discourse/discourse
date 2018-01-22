class WebHookPostSerializer < PostSerializer

  attributes :topic_posts_count

  def include_topic_title?
    true
  end

  %i{
    can_view
    can_edit
    can_delete
    can_recover
    can_wiki
  }.each do |attr|
    define_method("include_#{attr}?") do
      false
    end
  end

  def topic_posts_count
    object.topic ? object.topic.posts_count : 0
  end

end
