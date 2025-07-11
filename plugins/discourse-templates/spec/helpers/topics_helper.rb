# frozen_string_literal: true

module DiscourseTemplates::TopicsHelper
  def serialize_topics(topics)
    JSON.parse(
      ActiveModel::ArraySerializer.new(
        topics,
        each_serializer: DiscourseTemplates::TemplatesSerializer,
      ).to_json,
    )
  end
end
