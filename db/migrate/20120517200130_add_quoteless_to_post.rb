# frozen_string_literal: true

class AddQuotelessToPost < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :quoteless, :boolean, default: false
  end
end
