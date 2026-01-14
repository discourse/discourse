# frozen_string_literal: true

class AddLocaleToTags < ActiveRecord::Migration[8.0]
  def change
    add_column :tags, :locale, :string, limit: 20
  end
end
