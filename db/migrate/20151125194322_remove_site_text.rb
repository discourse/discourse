# frozen_string_literal: true

class RemoveSiteText < ActiveRecord::Migration[4.2]
  def change
    execute "INSERT INTO translation_overrides (locale, translation_key, value, created_at, updated_at)
                    SELECT '#{I18n.locale}',
                           CASE
                            WHEN text_type = 'usage_tips' THEN 'system_messages.usage_tips.text_body_template'
                            WHEN text_type = 'education_new_topic' THEN 'education.new-topic'
                            WHEN text_type = 'education_new_reply' THEN 'education.new-reply'
                            WHEN text_type = 'login_required_welcome_message' THEN 'login_required.welcome_message'
                           END,
                           value,
                           created_at,
                           updated_at
                   FROM site_texts
                   WHERE text_type in ('usage_tips',
                                       'education_new_topic',
                                       'education_new_reply',
                                       'login_required_welcome_message')"
    drop_table :site_texts
  end
end
