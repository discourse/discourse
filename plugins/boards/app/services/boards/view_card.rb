# frozen_string_literal: true

module Boards
  class ViewCard
    include Service::Base

    params { attribute :id, :integer }

    policy :is_logged_in
    model :card
    policy :can_view_card
    step :create_view_history

    private

    def is_logged_in(guardian:)
      guardian.authenticated?
    end

    def fetch_card(params:)
      Boards::Card.find_by(id: params.id)
    end

    def can_view_card(guardian:, card:)
      guardian.can_view_boards_card?(card)
    end

    def create_view_history(guardian:, card:)
      CardHistory.create!(
        card:,
        acting_user: guardian.user,
        action: CardHistory.actions[:card_viewed],
        board_id: card.board_id,
      )
    rescue ActiveRecord::RecordNotUnique
      # We only want to record one view per user per card per day,
      # see the index_discourse_kanban_card_histories_one_view_per_user_day index.
    end
  end
end
