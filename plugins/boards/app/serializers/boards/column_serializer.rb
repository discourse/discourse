# frozen_string_literal: true

module Boards
  class ColumnSerializer < ApplicationSerializer
    attributes :id,
               :title,
               :unicode_title,
               :icon,
               :position,
               :default_sort,
               :tag_id,
               :tag_name,
               :move_to_category_id,
               :move_to_assigned,
               :move_to_status,
               :cards,
               :color

    def tag_id
      visible_tag_id
    end

    def tag_name
      visible_tag_id ? tag_name_map[visible_tag_id] : nil
    end

    def cards
      sorted_cards.map do |card|
        CardSerializer.new(
          card,
          root: false,
          scope:,
          assignments_by_topic: @options[:assignments_by_topic],
          topic_users_by_topic: @options[:topic_users_by_topic],
          tags_by_id: @options[:tags_by_id],
        ).as_json
      end
    end

    def include_cards?
      @options.key?(:cards_by_column)
    end

    private

    def visible_tag_id
      @visible_tag_id ||= (object.tag_id if object.tag_id && tag_name_map.key?(object.tag_id))
    end

    def sorted_cards
      cards = cards_by_column[object.id] || []

      if object.recency?
        cards.sort_by { |card| [card.recency_at || Time.zone.at(0), card.id] }.reverse
      else
        cards.sort_by { |card| [card.position, card.id] }
      end
    end

    def cards_by_column
      @options[:cards_by_column] || {}
    end

    def tag_name_map
      @options[:tag_name_map] || {}
    end
  end
end
