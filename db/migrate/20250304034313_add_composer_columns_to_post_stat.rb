# frozen_string_literal: true

class AddComposerColumnsToPostStat < ActiveRecord::Migration[7.2]
  def change
    add_column :post_stats, :composer_version, :integer
    add_column :post_stats, :writing_device, :string
    add_column :post_stats, :writing_device_user_agent, :string
  end
end
