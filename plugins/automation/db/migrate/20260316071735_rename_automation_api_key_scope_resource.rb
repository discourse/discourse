# frozen_string_literal: true

class RenameAutomationApiKeyScopeResource < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE api_key_scopes
      SET resource = 'automation'
      WHERE resource = 'automations_trigger'
    SQL

    execute <<~SQL
      UPDATE api_key_scopes
      SET action = 'trigger_automation'
      WHERE resource = 'automation' AND action = 'post'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE api_key_scopes
      SET action = 'post'
      WHERE resource = 'automation' AND action = 'trigger_automation'
    SQL

    execute <<~SQL
      UPDATE api_key_scopes
      SET resource = 'automations_trigger'
      WHERE resource = 'automation'
    SQL
  end
end
