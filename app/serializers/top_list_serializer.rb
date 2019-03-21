class TopListSerializer < ApplicationSerializer
  attributes :can_create_topic, :draft, :draft_key, :draft_sequence

  def can_create_topic
    scope.can_create?(Topic)
  end

  TopTopic.periods.each do |period|
    attribute period

    define_method(period) do
      if object.send(period)
        TopicListSerializer.new(object.send(period), scope: scope).as_json
      end
    end
  end
end
