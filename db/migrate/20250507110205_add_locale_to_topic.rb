# frozen_string_literal: true

class AddLocaleToTopic < ActiveRecord::Migration[7.2]
  def change
    add_column :topics, :locale, :string, limit: 20
  end
end
