# frozen_string_literal: true

class ChangeIncomingEmailCreatedAtNull < ActiveRecord::Migration[6.0]
  def up
    # 9 signifies unknown
    DB.exec("UPDATE incoming_emails SET created_via = 9 WHERE created_via IS NULL")
    change_column_default :incoming_emails, :created_via, 9
    change_column_null :incoming_emails, :created_via, false
  end

  def down
    change_column_null :incoming_emails, :created_via, true
  end
end
