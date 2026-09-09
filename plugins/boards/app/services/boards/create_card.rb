# frozen_string_literal: true

module Boards
  class CreateCard
    include Service::Base

    options { attribute :constraint_fix }

    params do
      attribute :board_id, :integer
      attribute :column_id, :integer
      attribute :topic_id, :integer
      attribute :title, :string
      attribute :notes, :string
      attribute :after_card_id, :integer
      attribute :assigned_to_name, :string
      attribute :tag_ids, :array
      attribute :tag_names, :array

      validates :board_id, presence: true
      validates :column_id, presence: true
    end

    model :board
    policy :can_write
    model :column

    transaction do
      step :create_card
      step :create_card_history
    end

    private

    def fetch_board(params:)
      Board.find_by(id: params.board_id)
    end

    def can_write(board:, guardian:)
      guardian.can_write_boards_board?(board)
    end

    def fetch_column(board:, params:)
      board.columns.find_by(id: params.column_id)
    end

    def create_card(board:, column:, params:, guardian:, options:)
      context[:card] = if params.topic_id.present?
        build_topic_card(board, column, params, guardian, options:)
      else
        build_floater_card(board, column, params, guardian)
      end
    end

    def create_card_history(card:, guardian:)
      CardHistory.create!(
        card:,
        acting_user: guardian.user,
        action: CardHistory.actions[:card_created],
        board_id: card.board_id,
      )
    end

    def build_topic_card(board, column, params, guardian, options:)
      topic = Topic.find_by(id: params.topic_id)
      raise Discourse::NotFound if topic.nil?
      raise Discourse::NotFound unless guardian.can_see?(topic)
      if Category.exists?(topic_id: topic.id)
        raise Discourse::InvalidParameters.new(I18n.t("boards.errors.category_definition_topic"))
      end

      Card.transaction do
        constraint_fix = options.constraint_fix.presence || context[:constraint_fix]

        if constraint_fix.present?
          ConstraintFixer.apply!(fix: constraint_fix, board:, topic:, guardian:)
        end

        unless board.topic_will_match_after_mutation?(topic, column)
          raise Discourse::InvalidParameters.new(
                  I18n.t("boards.errors.topic_does_not_match_constraints"),
                )
        end

        card = board.cards.find_or_initialize_by(topic_id: topic.id, column_id: column.id)
        card.card_type = :topic
        card.updated_by_id = guardian.user.id
        card.created_by_id ||= guardian.user.id

        if card.new_record?
          CardOrdering.append_to_column!(card, column)
        else
          CardOrdering.place_card!(card, column:, after_card_id: params.after_card_id)
        end

        card.save!
        apply_column_mutations!(topic, column, guardian)
        card
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => error
      unless unique_topic_card_violation?(error) ||
               board.cards.where(topic_id: topic.id, column_id: column.id).exists?
        raise
      end

      card = board.cards.find_by!(topic_id: topic.id, column_id: column.id)
      card.updated_by_id = guardian.user.id
      card.created_by_id ||= guardian.user.id
      CardOrdering.place_card!(card, column:, after_card_id: params.after_card_id)
      card.save!
      apply_column_mutations!(topic, column, guardian)
      card
    end

    def apply_column_mutations!(topic, column, guardian)
      if column.tag_id.blank? && column.move_to_category_id.blank? &&
           column.move_to_assigned.blank? && column.move_to_status.blank?
        return
      end
      return unless guardian.can_edit?(topic)
      TopicMutator.apply!(topic:, column:, guardian:)
    end

    def build_floater_card(board, column, params, guardian)
      tag_ids = resolve_all_tag_ids(params.tag_ids, params.tag_names, guardian)
      card =
        board.cards.build(
          card_type: :floater,
          title: params.title,
          notes: params.notes,
          tag_ids:,
          assigned_to: resolve_assignee(params.assigned_to_name, guardian),
          created_by_id: guardian.user.id,
          updated_by_id: guardian.user.id,
        )

      LooseCardTagMutator.apply_to_card!(card:, column:)
      CardOrdering.append_to_column!(card, column)
      card.save!
      card
    end

    def resolve_assignee(name, guardian)
      return nil if name.blank?

      unless guardian.can_assign?
        raise Discourse::InvalidAccess.new(I18n.t("boards.errors.cannot_assign"))
      end

      user = User.find_by_username(name)
      return user if user&.active

      group = Group.find_by(name: name)
      return group if group && guardian.can_see_group?(group)

      raise Discourse::InvalidParameters.new(I18n.t("boards.errors.invalid_assignee", name: name))
    end

    def unique_topic_card_violation?(error)
      [error, error.cause, error.cause&.cause].compact.any? do |candidate|
        candidate.message.include?("idx_kanban_cards_unique_topic_per_column") ||
          topic_card_constraint_name(candidate) == "idx_kanban_cards_unique_topic_per_column"
      end
    end

    def resolve_all_tag_ids(tag_ids, tag_names, guardian)
      ids = Card.normalize_visible_tag_ids!(tag_ids, guardian)
      names = Array(tag_names).compact_blank
      if names.present?
        tags = DiscourseTagging.find_or_create_tags!(names, guardian)
        ids = Card.normalize_visible_tag_ids!(ids + tags.map(&:id), guardian)
      end
      ids
    end

    def topic_card_constraint_name(error)
      return unless defined?(PG::Result)
      return unless error.respond_to?(:result)

      error.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    end
  end
end
