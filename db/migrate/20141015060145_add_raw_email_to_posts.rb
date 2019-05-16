# frozen_string_literal: true

class AddRawEmailToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :raw_email, :text
  end
end
