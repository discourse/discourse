# frozen_string_literal: true

class AddAiSearchDiscoveriesToUserOptions < ActiveRecord::Migration[7.2]
  def change
    add_column :user_options, :ai_search_discoveries, :boolean, default: true, null: false
  end
end
