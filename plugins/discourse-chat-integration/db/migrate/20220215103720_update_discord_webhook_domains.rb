# frozen_string_literal: true

class UpdateDiscordWebhookDomains < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      UPDATE plugin_store_rows psr
      SET value = REPLACE(value, 'discordapp.com', 'discord.com')
      WHERE psr.plugin_name = 'discourse-chat-integration'
      AND psr.key LIKE 'channel:%'
      AND psr.type_name = 'JSON'
      AND psr.value::json ->> 'provider' = 'discord'
      AND psr.value::json ->> 'data' LIKE '%https://discordapp.com/%'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
