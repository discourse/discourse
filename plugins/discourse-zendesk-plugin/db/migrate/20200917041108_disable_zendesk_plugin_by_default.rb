# frozen_string_literal: true

class DisableZendeskPluginByDefault < ActiveRecord::Migration[6.0]
  def change
    # enable Zendesk plugin for sites that have configured Zendesk API token
    zendesk_email =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'zendesk_jobs_email'").first
    zendesk_api_token =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'zendesk_jobs_api_token'").first
    DB.exec(<<~SQL) if zendesk_email.present? && zendesk_api_token.present?
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        VALUES ('zendesk_enabled', 5, 't', now(), now())
        ON CONFLICT (name)
        DO NOTHING
      SQL
  end
end
