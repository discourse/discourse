class TopListSerializer < ApplicationSerializer

  attributes :can_create_topic,
             :draft,
             :draft_key,
             :draft_sequence

  def can_create_topic
    scope.can_create?(Topic)
  end

  TopTopic.periods.each do |period|
    attribute period

    define_method(period) do
      TopicListSerializer.new(object.send(period), scope: scope).as_json if object.send(period)
    end

  end

end
