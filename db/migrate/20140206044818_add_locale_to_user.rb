# frozen_string_literal: true

class AddLocaleToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :locale, :string, limit: 10
  end
end
