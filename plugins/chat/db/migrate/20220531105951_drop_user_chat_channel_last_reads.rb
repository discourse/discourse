# frozen_string_literal: true

require "migration/table_dropper"

# usage has been dropped in https://github.com/discourse/discourse-chat/commit/1c110b71b28411dc7ac3ab9e3950e0bbf38d7970
# but table never got dropped
class DropUserChatChannelLastReads < ActiveRecord::Migration[7.0]
  DROPPED_TABLES = %i[user_chat_channel_last_reads].freeze

  def up
    DROPPED_TABLES.each { |table| Migration::TableDropper.execute_drop(table) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
