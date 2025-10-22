# frozen_string_literal: true
class PreserveDisableNarrativeBotWelcomePostForModifiedTranslations < ActiveRecord::Migration[8.0]
  def up
    return if !Migration::Helpers.existing_site?

    system_messages_welcome_user_subject_template_has_overridden =
      DB
        .query_single(
          "SELECT value FROM translation_overrides WHERE translation_key = 'system_messages.welcome_user.subject_template' LIMIT 1",
        )
        .first
        .present?

    system_messages_welcome_user_text_body_template_has_overridden =
      DB
        .query_single(
          "SELECT value FROM translation_overrides WHERE translation_key = 'system_messages.welcome_user.text_body_template' LIMIT 1",
        )
        .first
        .present?

    discourse_narrative_bot_new_user_narrative_hello_message_has_overridden =
      DB
        .query_single(
          "SELECT value FROM translation_overrides WHERE translation_key = 'discourse_narrative_bot.new_user_narrative.hello_message' LIMIT 1",
        )
        .first
        .present?

    # If any of these has been overridden in any language, we want to preserve the
    # old default value for the site setting `disable_discourse_narrative_bot_welcome_post`.
    if system_messages_welcome_user_subject_template_has_overridden ||
         system_messages_welcome_user_text_body_template_has_overridden ||
         discourse_narrative_bot_new_user_narrative_hello_message_has_overridden
      # Type 5 is 'boolean'
      DB.exec(<<~SQL)
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('disable_discourse_narrative_bot_welcome_post', 5, 'f', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
