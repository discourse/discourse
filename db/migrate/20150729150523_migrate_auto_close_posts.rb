# frozen_string_literal: true

class MigrateAutoClosePosts < ActiveRecord::Migration[4.2]
  def up
    I18n.overrides_disabled do
      strings = []
      %w(days hours lastpost_days lastpost_hours lastpost_minutes).map do |k|
        strings += I18n.t("topic_statuses.autoclosed_enabled_#{k}").values.map { |s| s.sub("%{count}", "\\d+") }
      end

      sql = <<~SQL
        UPDATE posts
        SET action_code = 'autoclosed.enabled',
            post_type = 3
        WHERE post_type = 2 AND (
          #{strings.map { |s| "raw ~* #{ActiveRecord::Base.connection.quote(s)}" }.join(' OR ')}
        )
      SQL

      execute sql
    end
  end
end
