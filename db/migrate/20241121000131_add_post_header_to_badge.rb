# frozen_string_literal: true
class AddPostHeaderToBadge < ActiveRecord::Migration[7.1]
  def change
    add_column :badges, :show_in_post_header, :boolean, default: false, null: false
  end
end
