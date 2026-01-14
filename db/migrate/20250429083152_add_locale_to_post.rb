# frozen_string_literal: true

class AddLocaleToPost < ActiveRecord::Migration[7.2]
  def change
    add_column :posts, :locale, :string, limit: 20
  end
end
