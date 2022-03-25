# frozen_string_literal: true

class RemoveAccessControlPostFk < ActiveRecord::Migration[6.0]
  def change
    remove_foreign_key(:uploads, column: :access_control_post_id) if foreign_key_exists?(:uploads, column: :access_control_post_id)
  end
end
