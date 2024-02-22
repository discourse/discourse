# frozen_string_literal: true

class MigrateDmChannels < ActiveRecord::Migration[7.0]
  def up
    DB.exec(
      "UPDATE chat_channels SET type='DirectMessageChannel', chatable_type='DirectMessage' WHERE chatable_type = 'DirectMessageChannel'",
    )
  end
end
