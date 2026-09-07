# frozen_string_literal: true

module Boards
  class BasicColumnSerializer < ApplicationSerializer
    attributes :id, :unicode_title, :icon, :color, :topic_is_member?, :topic_card_id

    def include_topic_is_member?
      @options[:board_memberships].present?
    end

    def topic_is_member?
      @options[:board_memberships].map { |membership| membership.column_id }.include?(object.id)
    end

    def topic_card_id
      @options[:board_memberships].find { |membership| membership.column_id == object.id }&.id
    end
  end
end
