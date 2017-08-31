class MigrateOldModeratorPosts < ActiveRecord::Migration[4.2]

  def migrate_key(action_code)
    I18n.overrides_disabled do
      text = I18n.t("topic_statuses.#{action_code.gsub('.', '_')}")

      execute "UPDATE posts SET action_code = '#{action_code}', raw = '', cooked = '', post_type = 3 where post_type = 2 AND raw = #{ActiveRecord::Base.connection.quote(text)}"
    end
  end

  def up
    migrate_key('closed.enabled')
    migrate_key('closed.disabled')
    migrate_key('archived.enabled')
    migrate_key('archived.disabled')
    migrate_key('pinned.enabled')
    migrate_key('pinned.disabled')
    migrate_key('pinned_globally.enabled')
    migrate_key('pinned_globally.disabled')
  end
end
