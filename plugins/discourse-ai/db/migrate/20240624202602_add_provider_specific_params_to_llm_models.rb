# frozen_string_literal: true
class AddProviderSpecificParamsToLlmModels < ActiveRecord::Migration[7.0]
  def up
    open_ai_organization = fetch_setting("ai_openai_organization")

    DB.exec(<<~SQL, organization: open_ai_organization) if open_ai_organization
      UPDATE llm_models
      SET provider_params = jsonb_build_object('organization', :organization)
      WHERE provider = 'open_ai' AND provider_params IS NULL
    SQL

    bedrock_region = fetch_setting("ai_bedrock_region") || "us-east-1"
    bedrock_access_key_id = fetch_setting("ai_bedrock_access_key_id")

    DB.exec(<<~SQL, key_id: bedrock_access_key_id, region: bedrock_region) if bedrock_access_key_id
      UPDATE llm_models
      SET
        provider_params = jsonb_build_object('access_key_id', :key_id, 'region', :region),
        name = CASE name WHEN 'claude-2' THEN 'anthropic.claude-v2:1'
                         WHEN 'claude-3-haiku' THEN 'anthropic.claude-3-haiku-20240307-v1:0'
                         WHEN 'claude-3-sonnet' THEN 'anthropic.claude-3-sonnet-20240229-v1:0'
                         WHEN 'claude-instant-1' THEN 'anthropic.claude-instant-v1'
                         WHEN 'claude-3-opus' THEN 'anthropic.claude-3-opus-20240229-v1:0'
                         WHEN 'claude-3-5-sonnet' THEN 'anthropic.claude-3-5-sonnet-20240620-v1:0'
                         ELSE name
                         END
      WHERE provider = 'aws_bedrock' AND provider_params IS NULL
    SQL
  end

  def fetch_setting(name)
    DB.query_single(
      "SELECT value FROM site_settings WHERE name = :setting_name",
      setting_name: name,
    ).first
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
