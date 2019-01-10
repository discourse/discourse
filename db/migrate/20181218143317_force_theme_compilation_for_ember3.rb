class ForceThemeCompilationForEmber3 < ActiveRecord::Migration[5.2]
  def up
    ThemeField.force_recompilation!
    Theme.expire_site_cache!
  end
end
