# frozen_string_literal: true
class IgnoreChannelWideMentionToUserOptions < ActiveRecord::Migration[6.1]
  def change
    add_column :user_options, :ignore_channel_wide_mention, :boolean, null: true
  end
end
