# frozen_string_literal: true

class ChangeDiscourseRewindSharePubliclyDefaultToFalse < ActiveRecord::Migration[7.2]
  def up
    change_column_default :user_options, :discourse_rewind_share_publicly, false
    execute "UPDATE user_options SET discourse_rewind_share_publicly = false"
  end

  def down
    change_column_default :user_options, :discourse_rewind_share_publicly, true
    execute "UPDATE user_options SET discourse_rewind_share_publicly = true"
  end
end
