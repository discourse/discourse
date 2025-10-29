# frozen_string_literal: true

class Jobs::IndexTopicLocalizationForSearch < Jobs::Base
  def execute(args)
    topic_id = args[:topic_id]
    return if topic_id.blank?

    topic = Topic.find_by(id: topic_id)
    return if topic.blank?

    SearchIndexer.index_topic_localizations(topic)
  end
end
