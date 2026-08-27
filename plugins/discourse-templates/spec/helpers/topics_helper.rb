# frozen_string_literal: true

module DiscourseTemplates::TopicsHelper
  def serialize_topics(topics, user = nil)
    guardian = user ? user.guardian : Guardian.new
    JSON.parse(
      ActiveModel::ArraySerializer.new(
        topics,
        each_serializer: DiscourseTemplates::TemplatesSerializer,
        scope: guardian,
      ).to_json,
    )
  end
end
