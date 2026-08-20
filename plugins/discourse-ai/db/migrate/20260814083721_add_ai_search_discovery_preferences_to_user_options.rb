# frozen_string_literal: true

class AddAiSearchDiscoveryPreferencesToUserOptions < ActiveRecord::Migration[8.0]
  def change
    add_column :user_options, :ai_search_discoveries_mode, :integer, default: 1, null: false
    add_column :user_options,
               :ai_search_discoveries_show_summary,
               :boolean,
               default: true,
               null: false
    add_column :user_options,
               :ai_search_discoveries_summary_detail,
               :integer,
               default: 1,
               null: false
    add_column :user_options,
               :ai_search_discoveries_related_count,
               :integer,
               default: 2,
               null: false
  end
end
