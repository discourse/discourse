# frozen_string_literal: true

require "migration/table_dropper"

class DropGithubUserInfos < ActiveRecord::Migration[6.0]
  DROPPED_TABLES = %i[github_user_infos].freeze

  def up
    DROPPED_TABLES.each { |table| Migration::TableDropper.execute_drop(table) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
