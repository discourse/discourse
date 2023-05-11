# frozen_string_literal: true

class AddIndexIdBakedVersionOnPosts < ActiveRecord::Migration[5.2]
  def change
    add_index :posts, %i[id baked_version], order: { id: :desc }, where: "(deleted_at IS NULL)"
  end
end
