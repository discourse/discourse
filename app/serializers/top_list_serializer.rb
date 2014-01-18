class TopListSerializer < ApplicationSerializer

  attribute :can_create_topic

  def can_create_topic
    scope.can_create?(Topic)
  end

  TopTopic.periods.each do |period|
    attribute period

    define_method(period) do
      TopicListSerializer.new(object[period], scope: scope).as_json if object[period]
    end

  end

end
