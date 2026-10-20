# frozen_string_literal: true

module KanbanDevBot
  module LifecycleService
    def run!
      params = context[:params]
      name = self.class.name.demodulize
      board_id = %w[UpdateBoard DestroyBoard].include?(name) ? params.id : params.board_id
      return super unless Lifecycle.enabled?(board_id)

      Lifecycle.lock do
        board = Boards::Board.find(board_id)
        guardian = context[:guardian]
        return super unless guardian
        return super unless guardian.can_write_board?(board) || guardian.can_unarchive_board?(board)
        card = nil
        target = nil
        accepting = false
        case name
        when "CreateCard", "MoveTopicToColumn"
          target = board.columns.find_by(id: params.column_id || params.to_column_id)
          if !Lifecycle.machine? && target &&
               (Lifecycle::BOT_COLUMNS + ["DONE"]).include?(target.title)
            Lifecycle.reject!("Create cards in BACKLOG or TODO.")
          end
          if params.topic_id.present? && board.cards.exists?(topic_id: params.topic_id)
            Lifecycle.reject!("Move the existing card instead of adding another placement.")
          end
        when "UpdateCard"
          if params.topic_id.present?
            Lifecycle.reject!("A development card cannot change its linked topic.")
          end
          card = board.cards.find_by(id: params.id)
          target = board.columns.find_by(id: params.column_id)
          raw = context[:raw_card_params] || context[:options]&.fetch(:raw_card_params, nil) || {}
          target ||= card&.column if raw.key?("after_card_id")
          if card && target && (target.id != card.column_id || raw.key?("after_card_id"))
            Lifecycle.check_move!(card, target)
            accepting =
              card.column.title == "REVIEW" && target.title == "DONE" && !Lifecycle.machine?
          end
        when "DestroyCard"
          cards = board.cards.where(id: params.id).to_a
          Lifecycle.check_delete!(cards)
        when "ClearColumn"
          cards = board.cards.where(column_id: params.column_id).to_a
          Lifecycle.check_delete!(cards)
        when "DestroyColumn", "UpdateColumn", "MoveColumn", "CreateColumn", "Archive", "Unarchive"
          Lifecycle.reject!("The bot workflow columns cannot be changed.") unless Lifecycle.machine?
        when "DestroyBoard"
          Lifecycle.reject!("The development board cannot be deleted while its bot is enabled.")
        when "UpdateBoard"
          raw = (context[:raw_board_params] || {}).with_indifferent_access
          if (raw.keys & %w[columns category_ids tag_ids tag_names archived]).any?
            Lifecycle.reject!("The bot workflow configuration cannot be changed.")
          end
        end
        result = super
        if context.success?
          if accepting
            Lifecycle.accept!(card.reload)
          elsif name == "DestroyCard"
            Lifecycle.deleted!(cards)
          end
        end
        result
      end
    end
  end

  module LifecycleClearColumn
    private

    def clear(board:, column:, guardian:)
      return super unless Lifecycle.enabled?(board.id)
      cards = clearable_cards(board, column, guardian).to_a
      Lifecycle.check_delete!(cards)
      cards.each do |card|
        if card.topic.present? && !card.topic.closed? && !guardian.can_close_topic?(card.topic)
          raise Discourse::InvalidAccess
        end
      end
      cards.each do |card|
        Boards::DestroyCard.call!(guardian: guardian, params: { board_id: board.id, id: card.id })
      end
    end
  end

  module LifecycleUpdateBoard
    private

    def remove_non_matching_cards(board:, guardian:)
      if Lifecycle.enabled?(board.id)
        context[:cards_removed_count] = 0
      else
        super
      end
    end
  end

  module LifecycleColumnsReplacer
    def replace!(board:, **kwargs)
      if Lifecycle.enabled?(board.id)
        Lifecycle.reject!("The bot workflow columns cannot be replaced.")
      end
      super
    end
  end

  module LifecycleColumnMutator
    def apply!(column:, **kwargs)
      if Lifecycle.enabled?(column.board_id) && !Lifecycle.machine?
        Lifecycle.reject!("The bot workflow columns cannot be changed.")
      end
      super
    end

    def destroy!(column:)
      if Lifecycle.enabled?(column.board_id)
        Lifecycle.reject!("The bot workflow columns cannot be deleted.")
      end
      super
    end
  end

  module LifecyclePostDestroyer
    def destroy
      return super unless Lifecycle.enabled? && @post.is_first_post?
      Lifecycle.lock do
        cards = Boards::Card.where(board_id: BOARD_ID, topic_id: @post.topic_id).to_a
        Lifecycle.check_delete!(cards)
        result = super
        Lifecycle.deleted!(cards) if !Post.exists?(@post.id) || !Topic.exists?(@post.topic_id)
        result
      end
    end
  end

  module LifecycleTopic
    def trash!(*args, **kwargs)
      return super unless Lifecycle.enabled?
      Lifecycle.lock do
        cards = Boards::Card.where(board_id: BOARD_ID, topic_id: id).to_a
        Lifecycle.check_delete!(cards)
        Lifecycle.deleted!(cards)
        super
      end
    end

    def destroy(*args, **kwargs)
      return super unless Lifecycle.enabled?
      Lifecycle.lock do
        cards = Boards::Card.where(board_id: BOARD_ID, topic_id: id).to_a
        Lifecycle.check_delete!(cards)
        Lifecycle.deleted!(cards)
        super
      end
    end
  end

  module LifecycleTopicSync
    def backfill_board(board)
      return if Lifecycle.enabled?(board.id)
      super
    end

    def fetch_sync_snapshot(topic)
      result = super
      if Lifecycle.enabled?
        result[:existing_cards].reject! { |row| row[1] == BOARD_ID }
        result[:matching_placements].reject! { |row| row[:board_id] == BOARD_ID }
      end
      result
    end

    def remove_topic(topic_id)
      return super unless Lifecycle.enabled?
      Lifecycle.lock do
        cards = Boards::Card.where(board_id: BOARD_ID, topic_id: topic_id).to_a
        Lifecycle.check_delete!(cards)
        Lifecycle.deleted!(cards)
        super
      end
    end
  end
end
