class RenameConvertPastedImagesQualitySiteSetting < ActiveRecord::Migration[4.2]
  def up
    execute "UPDATE site_settings SET name = 'png_to_jpg_quality' WHERE name = 'convert_pasted_images_quality'"
  end

  def down
    execute "UPDATE site_settings SET name = 'convert_pasted_images_quality' WHERE name = 'png_to_jpg_quality'"
  end
end
