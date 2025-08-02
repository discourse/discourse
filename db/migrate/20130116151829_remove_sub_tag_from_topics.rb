# frozen_string_literal: true

class RemoveSubTagFromTopics < ActiveRecord::Migration[4.2]
  def up
    remove_column :topics, :sub_tag
  end

  def down
    add_column :topics, :sub_tag, :string
  end
end
