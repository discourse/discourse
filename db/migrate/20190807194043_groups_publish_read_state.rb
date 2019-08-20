# frozen_string_literal: true

class GroupsPublishReadState < ActiveRecord::Migration[5.2]
  def change
    add_column :groups, :publish_read_state, :boolean, null: false, default: false
  end
end
