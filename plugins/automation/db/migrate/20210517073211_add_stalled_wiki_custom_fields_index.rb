# frozen_string_literal: true

class AddStalledWikiCustomFieldsIndex < ActiveRecord::Migration[6.1]
  def change
    add_index :post_custom_fields,
              :post_id,
              unique: true,
              name: "index_post_custom_fields_on_stalled_wiki_triggered_at",
              where: "name = 'stalled_wiki_triggered_at'"
  end
end
