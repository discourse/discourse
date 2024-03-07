# frozen_string_literal: true

class FixChatChannelSlugIndex < ActiveRecord::Migration[7.0]
  def up
    remove_index(:chat_channels, :slug)
    add_index :chat_channels, :slug, unique: true, where: "slug != ''"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
