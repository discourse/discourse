# frozen_string_literal: true

class MigrateChatChannels < ActiveRecord::Migration[7.0]
  def up
    DB.exec("UPDATE chat_channels SET type='CategoryChannel' WHERE chatable_type = 'Category'")
    DB.exec(
      "UPDATE chat_channels SET type='DMChannel' WHERE chatable_type = 'DirectMessageChannel'",
    )
  end
end
