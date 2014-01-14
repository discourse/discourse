class TopListSerializer < ApplicationSerializer

  TopTopic.periods.each do |period|
    attribute period

    define_method(period) do
      TopicListSerializer.new(object[period], scope: scope).as_json if object[period]
    end

  end

end
