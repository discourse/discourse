# frozen_string_literal: true

module Boards
  class MoveTopicToColumn
    include Service::Base

    params do
      attribute :board_id, :integer
      attribute :topic_id, :integer
      attribute :to_column_id, :integer
      attribute :after_card_id, :integer
      attribute :client_id, :string

      validates :board_id, presence: true
      validates :topic_id, presence: true
      validates :to_column_id, presence: true
    end

    model :board
    policy :can_write
    model :topic
    policy :can_see_topic
    policy :can_edit_topic
    model :column
    policy :topic_matches_constraints

    transaction do
      step :apply_topic_mutations
      model :card, :place_topic_card
    end

    only_if(:card_newly_created) { step :publish_card_created }
    only_if(:card_repositioned) { step :publish_card_moved }

    private

    def fetch_board(params:)
      Board.find_by(id: params.board_id)
    end

    def can_write(board:, guardian:)
      guardian.can_write_boards_board?(board)
    end

    def fetch_topic(params:)
      Topic.find_by(id: params.topic_id)
    end

    def can_see_topic(topic:, guardian:)
      guardian.can_see?(topic)
    end

    def can_edit_topic(topic:, guardian:)
      guardian.can_edit?(topic)
    end

    def fetch_column(board:, params:)
      board.columns.find_by(id: params.to_column_id)
    end

    def topic_matches_constraints(board:, topic:, column:)
      board.topic_will_match_after_mutation?(topic, column)
    end

    def apply_topic_mutations(topic:, column:, guardian:)
      TopicMutator.apply!(topic:, column:, guardian:)
    end

    def place_topic_card(board:, topic:, column:, params:, guardian:)
      card = board.cards.find_or_initialize_by(topic:, column:)

      card.assign_attributes(card_type: :topic, updated_by_id: guardian.user.id)
      card.created_by_id ||= guardian.user.id

      if card.new_record?
        CardOrdering.append_to_column!(card, column)
        card.save!
      else
        CardOrdering.place_card!(card, column:, after_card_id: params.after_card_id)
      end

      card
    end

    def card_newly_created(card:)
      card.previously_new_record?
    end

    def card_repositioned(card:)
      !card.previously_new_record?
    end

    def publish_card_created(board:, card:, params:)
      payload = CardSerializer.new(card, root: false).as_json
      Publisher.publish_card_created!(board, payload, client_id: params.client_id)
    end

    def publish_card_moved(board:, card:, params:)
      payload = CardSerializer.new(card, root: false).as_json
      Publisher.publish_card_moved!(board, payload, client_id: params.client_id)
    end
  end
end
