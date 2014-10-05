class RemoveEmailInAddressSetting < ActiveRecord::Migration
  def up
    uncat_id = ActiveRecord::Base.exec_sql("SELECT value FROM site_settings WHERE name = 'uncategorized_category_id'").first
    cat_id_r = ActiveRecord::Base.exec_sql("SELECT value FROM site_settings WHERE name = 'email_in_category'").first
    email_r = ActiveRecord::Base.exec_sql("SELECT value FROM site_settings WHERE name = 'email_in_address'").first
    if email_r
      category_id = uncat_id["value"].to_i
      category_id = cat_id_r["value"].to_i if cat_id_r
      email = email_r["value"]
      ActiveRecord::Base.exec_sql("UPDATE categories SET email_in = ? WHERE id = ?", email, category_id)
    end

    ActiveRecord::Base.exec_sql("DELETE FROM site_settings WHERE name = 'email_in_category' OR name = 'email_in_address'")
  end

  def down
    # this change is backwards-compatible
  end
end
