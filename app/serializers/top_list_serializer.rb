# frozen_string_literal: true

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
      if resolved = object.public_send(period)
        TopicListSerializer.new(resolved, scope: scope).as_json
      end
    end

  end

end
