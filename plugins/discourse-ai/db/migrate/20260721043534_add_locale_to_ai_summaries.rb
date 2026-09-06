# frozen_string_literal: true

class AddLocaleToAiSummaries < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_summaries, :locale, :string, limit: 20
  end
end
