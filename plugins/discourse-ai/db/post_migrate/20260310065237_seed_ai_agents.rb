# frozen_string_literal: true

class SeedAiAgents < ActiveRecord::Migration[7.2]
  def up
    fixture_path =
      Rails.root.join("plugins", "discourse-ai", "db", "fixtures", "agents", "603_ai_agents.rb")
    load(fixture_path) if File.exist?(fixture_path) # rubocop:disable Discourse/Plugins/UseRequireRelative
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
