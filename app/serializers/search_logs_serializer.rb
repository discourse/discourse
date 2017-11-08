class SearchLogsSerializer < ApplicationSerializer
  attributes :term,
             :searches,
             :click_through,
             :clicked_topic_id,
             :topic_title,
             :topic_url,
             :unique

  def topic_title
    object&.topic&.title
  end

  def topic_url
    object&.topic&.url
  end
end
