# frozen_string_literal: true

class FillPersonalMessageEnabledGroupsBasedOnDeprecatedSettings < ActiveRecord::Migration[7.0]
  def up
    enable_personal_messages_raw =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'enable_personal_messages'",
      ).first
    enable_personal_messages =
      enable_personal_messages_raw.blank? || enable_personal_messages_raw == "t"

    min_trust_to_send_messages_raw =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'min_trust_to_send_messages'",
      ).first
    min_trust_to_send_messages =
      (min_trust_to_send_messages_raw.blank? ? 1 : min_trust_to_send_messages_raw).to_i

    # default to TL1, Group::AUTO_GROUPS[:trust_level_1] is 11
    personal_message_enabled_groups = "11"

    if min_trust_to_send_messages != 1
      # Group::AUTO_GROUPS[:trust_level_N] range from 10-14
      personal_message_enabled_groups = "1#{min_trust_to_send_messages}"
    end

    # only allow staff if the setting was previously disabled, Group::AUTO_GROUPS[:staff] is 3
    personal_message_enabled_groups = "3" if !enable_personal_messages

    # data_type 20 is group_list
    DB.exec(
      "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
      VALUES('personal_message_enabled_groups', :setting, '20', NOW(), NOW())",
      setting: personal_message_enabled_groups,
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
