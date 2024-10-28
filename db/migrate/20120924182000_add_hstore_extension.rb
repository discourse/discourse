# frozen_string_literal: true

class AddHstoreExtension < ActiveRecord::Migration[4.2]
  def up
    execute "CREATE EXTENSION IF NOT EXISTS hstore"
  end

  def down
    execute "DROP EXTENSION hstore"
  end
end
