# frozen_string_literal: true

class ChangeAllowUploadedAvatars < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET data_type = 7, value = (CASE WHEN value = 'f' THEN 'disabled' ELSE '0' END)
      WHERE name = 'allow_uploaded_avatars'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE site_settings
      SET data_type = 5, value = (CASE WHEN value = 'disabled' THEN 'f' ELSE 't' END)
      WHERE name = 'allow_uploaded_avatars'
    SQL
  end
end
