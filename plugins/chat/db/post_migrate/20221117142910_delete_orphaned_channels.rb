# frozen_string_literal: true

class DeleteOrphanedChannels < ActiveRecord::Migration[7.0]
  def up
    DB.exec(
      "DELETE FROM chat_channels WHERE chatable_type = 'Category' AND type = 'CategoryChannel' AND NOT EXISTS (SELECT * FROM categories WHERE categories.id = chat_channels.chatable_id)",
    )
  end
end
