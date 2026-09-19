# frozen_string_literal: true

module Boards
  class Column < ActiveRecord::Base
    self.table_name = "discourse_kanban_columns"
    self.ignored_columns = %w[wip_limit filter_query move_to_tag]

    belongs_to :board, class_name: "Boards::Board", inverse_of: :columns
    belongs_to :move_to_category, class_name: "Category", optional: true
    belongs_to :tag, optional: true
    has_many :cards, class_name: "Boards::Card", dependent: :nullify, inverse_of: :column
    has_many :history,
             ->(column) { where(board_id: column.board_id).order(created_at: :asc) },
             class_name: "Boards::BoardHistory",
             inverse_of: :column

    enum :default_sort, { priority: 0, recency: 1 }, default: :priority

    validates :title, presence: true
    validates :position, presence: true
    # Stored as a bare hex (no leading "#"), like core's category color. The
    # palette presets live in JS; here we only validate the shape.
    validates :color, format: { with: /\A(\h{3}|\h{6})\z/ }, allow_nil: true

    def matches_topic?(topic)
      tag_id.present? && topic.tag_ids.include?(tag_id)
    end

    def unicode_title
      Emoji.gsub_emoji_to_unicode(title)
    end
  end
end

# == Schema Information
#
# Table name: discourse_kanban_columns
#
#  id                  :bigint           not null, primary key
#  color               :string
#  default_sort        :integer          default("priority"), not null
#  icon                :string
#  move_to_assigned    :string
#  move_to_status      :string
#  position            :integer          default(0), not null
#  title               :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  board_id            :bigint           not null
#  move_to_category_id :bigint
#  tag_id              :integer
#
# Indexes
#
#  idx_kanban_columns_board_id        (board_id)
#  idx_kanban_columns_board_position  (board_id,position)
#  idx_kanban_columns_tag_id          (tag_id)
#
# Foreign Keys
#
#  fk_rails_...  (board_id => discourse_kanban_boards.id) ON DELETE => cascade
#  fk_rails_...  (move_to_category_id => categories.id) ON DELETE => nullify
#
