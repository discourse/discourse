# frozen_string_literal: true

class MarkChatThreadTitleTemplateReadonly < ActiveRecord::Migration[8.0]
  def up
    Migration::ColumnDropper.mark_readonly(:voice_rooms, :chat_thread_title_template)
  end

  def down
    Migration::ColumnDropper.drop_readonly(:voice_rooms, :chat_thread_title_template)
  end
end
