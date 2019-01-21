class EnableContentSecurityPolicyForNewSites < ActiveRecord::Migration[5.2]
  def up
    return if Rails.env.test?
    return if row_exists?

    if instance_is_new?
      execute "INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
               VALUES ('content_security_policy', 5, 't', now(), now())"
    end
  end

  def down
    # Don't undo, up method only enables CSP if row isn't already there and if instance is new
  end

  def row_exists?
    DB.query("SELECT 1 AS one FROM site_settings where name='content_security_policy'").present?
  end

  def instance_is_new?
    post = DB.query_single("SELECT created_at FROM posts ORDER BY created_at ASC LIMIT 1")
    return post.blank? || (post.present? && post.first > 1.week.ago)
  end

end
