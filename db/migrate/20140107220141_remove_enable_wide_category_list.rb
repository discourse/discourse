class RemoveEnableWideCategoryList < ActiveRecord::Migration[4.2]
  def up
    execute "DELETE FROM site_settings WHERE name = 'enable_wide_category_list'"
  end

  def down
    # Nothing. Default site setting value will be used.
  end
end
