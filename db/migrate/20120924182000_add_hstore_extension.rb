# frozen_string_literal: true

class AddHstoreExtension < ActiveRecord::Migration[4.2]
  def self.up
    execute "CREATE EXTENSION IF NOT EXISTS hstore"
  end

  def self.down
    execute "DROP EXTENSION hstore"
  end
end
