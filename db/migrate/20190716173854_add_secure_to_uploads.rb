# frozen_string_literal: true

class AddSecureToUploads < ActiveRecord::Migration[5.2]
  def up
    add_column :uploads, :secure, :boolean, default: false, null: false

    if SiteSetting.prevent_anons_from_downloading_files
      Upload.find_each do |upload|
        next if FileHelper.is_supported_image?(upload.original_filename)
        next if upload.for_theme || upload.for_site_setting

        execute("UPDATE uploads SET secure = 't' WHERE id = '#{upload.id}'")
      end
    end
  end

  def down
    remove_column :uploads, :secure
  end
end
