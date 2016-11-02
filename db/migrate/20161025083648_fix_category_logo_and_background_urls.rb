class FixCategoryLogoAndBackgroundUrls < ActiveRecord::Migration
  def up
    return true if Discourse.asset_host.blank?

    Category.exec_sql <<-SQL
      UPDATE categories
         SET logo_url = replace(logo_url, '#{Discourse.asset_host}', '')
           , background_url = replace(background_url, '#{Discourse.asset_host}', '')
    SQL
  end

  def down
  end
end
