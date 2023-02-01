# frozen_string_literal: true

class AddTrigramIndexesToUsers < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index(
      :users,
      :username_lower,
      using: "gist",
      opclass: :gist_trgm_ops,
      algorithm: :concurrently,
    )
    add_index(:users, :name, using: "gist", opclass: :gist_trgm_ops, algorithm: :concurrently)
  end
end
