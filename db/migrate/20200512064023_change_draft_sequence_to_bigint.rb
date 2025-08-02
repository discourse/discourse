# frozen_string_literal: true

class ChangeDraftSequenceToBigint < ActiveRecord::Migration[6.0]
  def change
    change_column :drafts, :sequence, :bigint, default: 0, null: false
    change_column :draft_sequences, :sequence, :bigint, null: false
  end
end
