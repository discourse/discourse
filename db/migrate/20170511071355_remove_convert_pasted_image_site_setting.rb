# frozen_string_literal: true

class RemoveConvertPastedImageSiteSetting < ActiveRecord::Migration[4.2]
  def up
    execute "DELETE FROM site_settings WHERE name = 'convert_pasted_images_to_hq_jpg'"
  end

  def down
  end
end
