# frozen_string_literal: true

class DisableAskAiBotAgents < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE ai_agents SET enabled = FALSE WHERE id IN (-40, -41)"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
