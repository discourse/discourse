class TopListSerializer < ApplicationSerializer

  attributes :can_create_topic,
             :yearly,
             :monthly,
             :weekly,
             :daily

  def can_create_topic
    scope.can_create?(Topic)
  end

  TopTopic.periods.each do |period|
    define_method(period) do
      TopicListSerializer.new(object[period], scope: scope).as_json
    end
  end

end
