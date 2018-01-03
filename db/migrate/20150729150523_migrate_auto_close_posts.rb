class MigrateAutoClosePosts < ActiveRecord::Migration[4.2]
  def up
    I18n.overrides_disabled do
      strings = []
      %w(days hours lastpost_days lastpost_hours lastpost_minutes).map do |k|
        strings << I18n.t("topic_statuses.autoclosed_enabled_#{k}.one")
        strings << I18n.t("topic_statuses.autoclosed_enabled_#{k}.other").sub("%{count}", "\\d+")
      end

      sql = "UPDATE posts SET action_code = 'autoclosed.enabled', post_type = 3 "
      sql << "WHERE post_type = 2 AND ("
      sql << strings.map { |s| "raw ~* #{ActiveRecord::Base.connection.quote(s)}" }.join(' OR ')
      sql << ")"

      execute sql
    end
  end
end
