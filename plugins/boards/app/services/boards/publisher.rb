# frozen_string_literal: true

module Boards
  module Publisher
    CHANNEL_PREFIX = "/boards"

    def self.publish_card_created!(board, card_payload, client_id:)
      publish_card_event!(board, "card_created", card_payload, client_id:)
    end

    def self.publish_card_updated!(board, card_payload, client_id:)
      publish_card_event!(board, "card_updated", card_payload, client_id:)
    end

    def self.publish_card_moved!(board, card_payload, old_column_id = nil, acting_user:, client_id:)
      new_column_id = card_payload.with_indifferent_access[:column_id]
      old_column_id ||= new_column_id
      if old_column_id.to_i != new_column_id.to_i
        DiscourseEvent.trigger(
          :boards_card_moved,
          board,
          card_payload.merge(old_column_id:),
          acting_user,
        )
      end
      publish_card_event!(board, "card_moved", card_payload, client_id:)
    end

    def self.publish_card_deleted!(board, card_id, topic:, client_id:)
      if topic
        publish_board_updated!(board, client_id:)
      else
        publish!(board, { type: "card_deleted", client_id: client_id, card_id: card_id })
      end
    end

    def self.publish_column_cleared!(board, column_id, client_id:)
      publish!(board, { type: "column_cleared", client_id: client_id, column_id: column_id })
    end

    def self.publish_board_updated!(board, client_id:)
      publish!(board, { type: "board_updated", client_id: client_id })
    end

    def self.publish_columns_reordered!(board, column_order, client_id:)
      publish!(
        board,
        { type: "columns_reordered", client_id: client_id, column_order: column_order },
      )
    end

    def self.publish_board_archived!(board, client_id:)
      publish!(board, { type: "board_archived", client_id: client_id })
    end

    def self.publish_board_unarchived!(board, client_id:)
      publish!(board, { type: "board_unarchived", client_id: client_id })
    end

    def self.publish_topic_memberships_changed!(topic, client_id:, refresh_stream: false)
      data = { reload_topic: true, client_id: }
      data[:refresh_stream] = true if refresh_stream

      MessageBus.publish("/topic/#{topic.id}", data, topic.secure_audience_publish_messages)
    end

    def self.publish_card_event!(board, type, card_payload, client_id:)
      if card_payload[:card_type] == "topic" || card_payload["card_type"] == "topic"
        publish_board_updated!(board, client_id:)
      else
        publish!(board, { type: type, client_id: client_id, card: card_payload })
      end
    end
    private_class_method :publish_card_event!

    def self.publish!(board, data)
      if data[:type] != "board_archived" &&
           (board.archived? || Boards::Board.where(id: board.id, archived: true).exists?)
        return
      end

      group_ids = board.permission_acl.group_ids_with_any_permission(%w[view edit manage])
      opts = {}
      # Anonymous viewers belong to no group, so a board readable by anonymous
      # users must broadcast to everyone rather than being group-restricted.
      if group_ids.present? && !group_ids.include?(Group::AUTO_GROUPS[:anonymous_users])
        opts[:group_ids] = group_ids
      end

      MessageBus.publish("#{CHANNEL_PREFIX}/#{board.id}", data, opts)
    end
    private_class_method :publish!
  end
end
