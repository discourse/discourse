# frozen_string_literal: true

module Boards
  class Card < ActiveRecord::Base
    self.table_name = "discourse_kanban_cards"

    belongs_to :board, class_name: "Boards::Board", inverse_of: :cards
    belongs_to :column, class_name: "Boards::Column", inverse_of: :cards, optional: true
    belongs_to :topic, -> { with_deleted }, optional: true
    belongs_to :created_by, class_name: "User", optional: true
    belongs_to :updated_by, class_name: "User", optional: true
    belongs_to :assigned_to, polymorphic: true, optional: true

    self.ignored_columns = %w[membership_mode labels]

    RECENCY_WINDOW = 1.week

    enum :card_type, { floater: 0, topic: 1 }, default: :floater

    validates :position, presence: true
    validates :column_id, presence: true

    validate :validate_type_integrity

    before_validation :normalize_card_type
    before_validation :initialize_column_changed_at, on: :create
    before_create :set_updated_by_id

    scope :with_column, -> { where.not(column_id: nil) }
    scope :ordered, -> { order(:position, :id) }

    class << self
      def normalize_tag_ids!(values)
        normalized_tag_ids = normalize_tag_id_values!(values)

        unknown_tag_ids = tag_ids_missing_from_database(normalized_tag_ids)
        return normalized_tag_ids if unknown_tag_ids.empty?

        raise Discourse::InvalidParameters.new(
                I18n.t("boards.errors.unknown_tag_ids", tag_ids: unknown_tag_ids.join(",")),
              )
      end

      def normalize_visible_tag_ids!(values, guardian)
        normalized_tag_ids = normalize_tag_ids!(values)
        return normalized_tag_ids if normalized_tag_ids.blank? || guardian&.is_admin?

        visible_tag_ids =
          DiscourseTagging.visible_tags(guardian).where(id: normalized_tag_ids).pluck(:id)
        hidden_tag_ids = normalized_tag_ids - visible_tag_ids
        return normalized_tag_ids if hidden_tag_ids.empty?

        raise Discourse::InvalidParameters.new(
                I18n.t("boards.errors.unknown_tag_ids", tag_ids: hidden_tag_ids.join(",")),
              )
      end

      def ordered_tags(tag_ids)
        normalized_tag_ids = normalize_tag_id_values!(tag_ids)
        return [] if normalized_tag_ids.blank?

        tags_by_id = Tag.where(id: normalized_tag_ids).index_by(&:id)
        normalized_tag_ids.filter_map { |tag_id| tags_by_id[tag_id] }
      end

      def preload_tags(cards)
        cards = Array(cards)
        return cards if cards.empty?

        all_tag_ids = cards.flat_map(&:tag_ids).uniq
        tags_by_id = all_tag_ids.empty? ? {} : Tag.where(id: all_tag_ids).index_by(&:id)

        cards.each do |card|
          sorted = card.tag_ids.filter_map { |id| tags_by_id[id] }.sort_by { |t| t.name.to_s }
          card.instance_variable_set(:@tags, sorted)
        end

        cards
      end

      private

      def tag_ids_missing_from_database(tag_ids)
        return [] if tag_ids.blank?

        existing_tag_ids = Tag.where(id: tag_ids).pluck(:id)
        tag_ids - existing_tag_ids
      end

      def normalize_tag_id_values!(values)
        raw_values = Array(values)
        raw_values.compact_blank.map { |value| Integer(value) }.reject(&:zero?).uniq
      rescue ArgumentError, TypeError
        raise Discourse::InvalidParameters.new(
                I18n.t("boards.errors.unknown_tag_ids", tag_ids: raw_values.join(",")),
              )
      end
    end

    def url
      "#{Discourse.base_url}/boards/#{board.slug}/#{board.id}/cards/#{id}"
    end

    def tags
      @tags ||= Tag.where(id: tag_ids).order(:name).to_a
    end

    def recency_at
      @recency_at ||= [column_changed_at, topic? ? topic&.bumped_at : updated_at].compact.max
    end

    def recent_for_column?
      recency_at.present? && recency_at >= RECENCY_WINDOW.ago
    end

    def resolved_title
      return title if topic_id.blank?
      topic&.title
    end

    def unicode_resolved_title
      Emoji.gsub_emoji_to_unicode(resolved_title)
    end

    def unicode_title
      Emoji.gsub_emoji_to_unicode(title)
    end

    private

    def set_updated_by_id
      self.updated_by_id = created_by_id
    end

    def initialize_column_changed_at
      return if column_changed_at.present? || column_id.blank?

      self.column_changed_at = updated_at || created_at || Time.zone.now
    end

    def normalize_card_type
      return if topic_id.blank?

      self.card_type = :topic
    end

    def validate_type_integrity
      if topic?
        errors.add(:topic_id, :blank) if topic_id.blank?
      else
        errors.add(:title, :blank) if title.blank?
        errors.add(:topic_id, :present) if topic_id.present?
      end
    end
  end
end

# == Schema Information
#
# Table name: discourse_kanban_cards
#
#  id                 :bigint           not null, primary key
#  assigned_to_type   :string
#  card_type          :integer          default("floater"), not null
#  column_changed_at  :datetime         not null
#  due_at             :datetime
#  inline_onebox_data :jsonb
#  notes              :text
#  position           :bigint           default(0), not null
#  tag_ids            :integer          default([]), not null, is an Array
#  title              :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  assigned_to_id     :bigint
#  board_id           :bigint           not null
#  column_id          :bigint
#  created_by_id      :bigint
#  topic_id           :bigint
#  updated_by_id      :bigint
#
# Indexes
#
#  idx_kanban_cards_assigned_to              (assigned_to_type,assigned_to_id)
#  idx_kanban_cards_board_column_position    (board_id,column_id,position)
#  idx_kanban_cards_board_id                 (board_id)
#  idx_kanban_cards_column_id                (column_id)
#  idx_kanban_cards_topic_id                 (topic_id)
#  idx_kanban_cards_unique_topic_per_column  (board_id,column_id,topic_id) UNIQUE WHERE ((topic_id IS NOT NULL) AND (column_id IS NOT NULL))
#
# Foreign Keys
#
#  fk_rails_...  (board_id => discourse_kanban_boards.id) ON DELETE => cascade
#  fk_rails_...  (column_id => discourse_kanban_columns.id) ON DELETE => nullify
#  fk_rails_...  (topic_id => topics.id) ON DELETE => cascade
#
