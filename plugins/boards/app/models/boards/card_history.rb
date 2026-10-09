# frozen_string_literal: true

module Boards
  class CardHistory < ActiveRecord::Base
    self.table_name = "discourse_kanban_card_histories"

    belongs_to :card, class_name: "Boards::Card"
    belongs_to :board, class_name: "Boards::Board"
    belongs_to :acting_user, class_name: "User"

    validates :action, presence: true
    validates :acting_user_id, presence: true
    validates :board_id, presence: true
    validates :card_id, presence: true

    enum :action,
         {
           card_created: 1,
           card_edited: 2,
           card_moved: 3,
           card_assigned: 4,
           card_unassigned: 5,
           card_deleted: 6,
           card_viewed: 7,
         }
  end
end

# == Schema Information
#
# Table name: discourse_kanban_card_histories
#
#  id             :bigint           not null, primary key
#  action         :integer          not null
#  details        :jsonb
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  acting_user_id :bigint           not null
#  board_id       :bigint           not null
#  card_id        :bigint           not null
#
# Indexes
#
#  index_discourse_kanban_card_histories_on_acting_user_id        (acting_user_id)
#  index_discourse_kanban_card_histories_on_board_id_and_card_id  (board_id,card_id)
#  index_discourse_kanban_card_histories_one_view_per_user_day    (board_id, card_id, acting_user_id, ((created_at)::date)) UNIQUE WHERE (action = 7)
#
