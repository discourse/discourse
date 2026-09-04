# frozen_string_literal: true

module Boards
  class BasicBoardSerializer < ApplicationSerializer
    attributes :id, :unicode_name, :slug, :columns, :topic_is_member?

    def columns
      object.columns.map do |column|
        BasicColumnSerializer.new(
          column,
          root: false,
          scope:,
          board_memberships: @options[:board_memberships],
        ).as_json
      end
    end

    def include_topic_is_member?
      @options[:board_memberships].present?
    end

    def topic_is_member?
      @options[:board_memberships].map { |membership| membership.board_id }.include?(object.id)
    end
  end
end
