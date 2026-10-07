# frozen_string_literal: true

module Boards
  class TopicBoardMemberships
    include Service::Base

    options { attribute :topics }

    model :cards_map, optional: true
    model :single_topic_memberships, optional: true

    private

    def fetch_cards_map(options:, guardian:)
      Action::BuildTopicBoardMembershipsMap.call(topics: options.topics, guardian:)
    end

    def fetch_single_topic_memberships(options:, cards_map:)
      return if options.topics.size > 1

      cards_map.fetch(options.topics.first.id, {}).values
    end
  end
end
