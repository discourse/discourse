# frozen_string_literal: true

class RenameSiteSettingAdsTxt < ActiveRecord::Migration[5.2]
  def up
    execute "UPDATE site_settings SET name = 'ads_txt' WHERE name = 'adsense_ads_txt'"
  end

  def down
    execute "UPDATE site_settings SET name = 'adsense_ads_txt' WHERE name = 'ads_txt'"
  end
end
