# frozen_string_literal: true

class AddMissingIdColumns < ActiveRecord::Migration[4.2]
  def up
    add_column :category_featured_topics, :id, :primary_key
    add_column :topic_users, :id, :primary_key
  end

  def down
    remove_column :category_featured_topics, :id
    remove_column :topic_users, :id
  end
end
