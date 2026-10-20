# frozen_string_literal: true

module KanbanDevBot
  module Lifecycle
    BOT_COLUMNS = ["IN PROGRESS", "REVIEW", "ARCHIVED"].freeze
    ACTIVE = %w[running stopping failed needs_attention].freeze
    PHASES = %w[
      integrating
      deploying
      publishing
      confirming
      integration_failed
      needs_attention
      done
    ].freeze

    def self.enabled?(board_id = BOARD_ID)
      !Rails.env.production? && SiteSetting.kanban_dev_bot_enabled && board_id.to_i == BOARD_ID
    end

    def self.run(card_or_id)
      id = card_or_id.respond_to?(:id) ? card_or_id.id : card_or_id
      PluginStore.get(STORE, "card-#{id}") || {}
    end

    def self.save(card_or_id, state)
      id = card_or_id.respond_to?(:id) ? card_or_id.id : card_or_id
      PluginStore.set(STORE, "card-#{id}", state)
    end

    def self.lock(&block)
      board = Boards::Board.find_by(id: BOARD_ID)
      return yield unless board
      board.with_lock(&block)
    end

    def self.machine
      previous = Thread.current[:kanban_dev_bot_machine]
      Thread.current[:kanban_dev_bot_machine] = true
      yield
    ensure
      Thread.current[:kanban_dev_bot_machine] = previous
    end

    def self.machine?
      Thread.current[:kanban_dev_bot_machine] == true
    end

    def self.accepted?(state)
      state["accepted_at"].present? && state["status"] != "archived"
    end

    def self.reject!(message)
      raise Discourse::InvalidParameters.new(message)
    end

    def self.check_delete!(cards)
      cards.each do |card|
        if accepted?(run(card))
          reject!("This card is being accepted. Wait for publication to finish.")
        end
      end
    end

    def self.deleted!(cards)
      cards.each do |card|
        state = run(card)
        next if state.empty?
        if state["status"] == "archived"
          state.delete("requested_action")
          state.merge!("deleted" => true, "cleanup_complete" => true)
          save(card, state)
          next
        end
        state["action_id"] = SecureRandom.uuid unless state["deleted"] &&
          state["requested_action"] == "cancel"
        state.merge!(
          "deleted" => true,
          "requested_action" => "cancel",
          "status" => "stopping",
          "phase" => "stopping",
          "cleanup_complete" => false,
        )
        save(card, state)
      end
    end

    def self.check_move!(card, target)
      return if machine?
      state = run(card)
      reject!("Use Cancel or Restart while the bot is working.") if ACTIVE.include?(state["status"])
      reject!("This card is being accepted. Wait for publication to finish.") if accepted?(state)
      reject!("This column is controlled by the bot.") if BOT_COLUMNS.include?(target.title)
      return unless target.title == "DONE"
      unless card.column.title == "REVIEW" && state["status"] == "review" &&
               state["version"] == card.column_changed_at.iso8601(6) &&
               state["commit"].to_s.match?(/\A[0-9a-f]{40}\z/)
        reject!("Only a completed, synchronized review can be accepted.")
      end
    end

    def self.accept!(card)
      state = run(card)
      state.merge!(
        "accepted_at" => Time.now.utc.iso8601(6),
        "accepted_commit" => state.fetch("commit"),
        "status" => "integrating",
        "phase" => "integrating",
        "version" => card.column_changed_at.iso8601(6),
      )
      save(card, state)
    end

    def self.presentation(card)
      state = run(card)
      busy = ACTIVE.include?(state["status"])
      accepted = accepted?(state)
      actions =
        if accepted
          state["status"] == "integration_failed" ? ["retry"] : []
        elsif state["status"] == "stopping"
          []
        elsif busy || state["status"] == "review"
          %w[cancel restart]
        else
          []
        end
      { run: state, can_move: !busy && !accepted, can_delete: !accepted, actions: actions }
    end

    def self.operations
      PluginStoreRow
        .where(plugin_name: STORE)
        .where("key LIKE 'card-%'")
        .filter_map do |row|
          next unless row.key.match?(/\Acard-\d+\z/)
          state = run(row.key.delete_prefix("card-"))
          if state["cleanup_complete"] || state.empty? || state["status"].in?(%w[archived stopped])
            next
          end
          { card_id: row.key.delete_prefix("card-").to_i, run: state }
        end
    end

    def self.request!(card, action, expected_run_id, expected_action_id = nil)
      state = run(card)
      unless state["run_id"].present? && state["run_id"] == expected_run_id
        reject!("Run superseded")
      end
      if state["requested_action"].present?
        reject!("Another action is already pending") unless state["requested_action"] == action
        return state
      end
      if expected_action_id.present? && expected_action_id != state["action_id"]
        reject!("Action superseded")
      end
      reject!("Action unavailable") if presentation(card)[:actions].exclude?(action)
      state.merge!(
        "requested_action" => action,
        "action_id" => SecureRandom.uuid,
        "diagnostic" => nil,
      )
      unless action == "retry"
        state["status"] = "stopping"
        state["phase"] = "stopping"
      end
      save(card, state)
      state
    end
  end
end
