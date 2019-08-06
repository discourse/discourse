# frozen_string_literal: true

class MigrateAutoClosePosts < ActiveRecord::Migration[4.2]
  def up
    I18n.overrides_disabled do
      strings = []

      %w(days hours lastpost_days lastpost_hours lastpost_minutes).each do |k|
        I18n.t("topic_statuses.autoclosed_enabled_#{k}").values.each do |s|
          strings << s.sub("%{count}", "\\d+")
        end
      end

      execute <<~SQL
        UPDATE posts
           SET action_code = 'autoclosed.enabled'
             , post_type = 3
         WHERE post_type = 2
           AND (#{strings.map { |s| "raw ~* #{ActiveRecord::Base.connection.quote(s)}" }.join(' OR ')})
      SQL
    end
  end
end
