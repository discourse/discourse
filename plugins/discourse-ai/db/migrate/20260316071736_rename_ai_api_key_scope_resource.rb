# frozen_string_literal: true

class RenameAiApiKeyScopeResource < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE api_key_scopes
      SET resource = 'ai'
      WHERE resource = 'discourse_ai'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE api_key_scopes
      SET resource = 'discourse_ai'
      WHERE resource = 'ai'
    SQL
  end
end
