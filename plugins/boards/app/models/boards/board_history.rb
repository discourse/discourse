# frozen_string_literal: true

module Boards
  class BoardHistory < ActiveRecord::Base
    self.table_name = "discourse_kanban_board_histories"

    belongs_to :board, class_name: "Boards::Board"
    belongs_to :acting_user, class_name: "User"
    belongs_to :column, class_name: "Boards::Column", optional: true

    validates :action, presence: true
    validates :acting_user_id, presence: true
    validates :board_id, presence: true

    enum :action,
         {
           board_created: 1,
           board_renamed: 2,
           board_constraints_changed: 3,
           board_slug_changed: 4,
           board_permissions_changed: 5,
           board_deleted: 6,
           board_viewed: 7,
           column_added: 8,
           column_renamed: 9,
           column_edited: 10,
           column_deleted: 11,
         }
  end
end

# == Schema Information
#
# Table name: discourse_kanban_board_histories
#
#  id             :bigint           not null, primary key
#  action         :integer          not null
#  details        :jsonb
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  acting_user_id :bigint           not null
#  board_id       :bigint           not null
#  column_id      :bigint
#
# Indexes
#
#  index_discourse_kanban_board_histories_on_acting_user_id      (acting_user_id)
#  index_discourse_kanban_board_histories_on_board_id            (board_id)
#  index_discourse_kanban_board_histories_on_column_id           (column_id)
#  index_discourse_kanban_board_histories_one_view_per_user_day  (board_id, acting_user_id, ((created_at)::date)) UNIQUE WHERE (action = 7)
#
