# frozen_string_literal: true
class UpdateDeleteMergedStubTopicsAfterDaysSetting < ActiveRecord::Migration[7.1]
  def up
    execute "UPDATE site_settings SET value = '-1' WHERE name = 'delete_merged_stub_topics_after_days' AND value = '0'"
  end

  def down
    execute "UPDATE site_settings SET value = '0' WHERE name = 'delete_merged_stub_topics_after_days' AND value = '-1'"
  end
end
