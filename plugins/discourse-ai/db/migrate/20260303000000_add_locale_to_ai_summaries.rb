# frozen_string_literal: true

class AddLocaleToAiSummaries < ActiveRecord::Migration[7.2]
  def change
    add_column :ai_summaries, :locale, :string, null: false, default: ""

    remove_index :ai_summaries, name: "idx_on_target_id_target_type_summary_type_3355609fbb"
    add_index :ai_summaries,
              %i[target_id target_type summary_type locale],
              unique: true,
              name: "idx_ai_summaries_on_target_type_id_summary_type_locale"
  end
end
