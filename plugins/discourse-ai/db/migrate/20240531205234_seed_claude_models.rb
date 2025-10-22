# frozen_string_literal: true

class SeedClaudeModels < ActiveRecord::Migration[7.0]
  def up
    claude_models = %w[claude-instant-1 claude-2 claude-3-haiku claude-3-sonnet claude-3-opus]

    models = []

    bedrock_secret_access_key = fetch_setting("ai_bedrock_secret_access_key")
    enabled_models = fetch_setting("ai_bot_enabled_chat_bots")&.split("|").to_a

    if bedrock_secret_access_key.present?
      bedrock_region = fetch_setting("ai_bedrock_region") || "us-east-1"

      claude_models.each do |cm|
        url =
          "https://bedrock-runtime.#{bedrock_region}.amazonaws.com/model/#{mapped_bedrock_model(cm)}/invoke"

        bot_id = claude_bot_id(cm)
        user_id = has_companion_user?(bot_id) ? bot_id : "NULL"

        enabled = enabled_models.include?(cm)
        models << "('#{display_name(cm)}', '#{cm}', 'aws_bedrock', 'DiscourseAi::Tokenizer::AnthropicTokenizer', 200000, '#{url}', '#{bedrock_secret_access_key}', #{user_id}, #{enabled}, NOW(), NOW())"
      end
    end

    anthropic_ai_api_key = fetch_setting("ai_anthropic_api_key")
    if anthropic_ai_api_key.present?
      claude_models.each do |cm|
        url = "https://api.anthropic.com/v1/messages"

        bot_id = claude_bot_id(cm)
        user_id = has_companion_user?(bot_id) ? bot_id : "NULL"

        enabled = enabled_models.include?(cm)
        models << "('#{display_name(cm)}', '#{cm}', 'anthropic', 'DiscourseAi::Tokenizer::AnthropicTokenizer', 200000, '#{url}', '#{anthropic_ai_api_key}', #{user_id}, #{enabled}, NOW(), NOW())"
      end
    end

    if models.present?
      rows = models.compact.join(", ")

      DB.exec(<<~SQL, rows: rows) if rows.present?
        INSERT INTO llm_models(display_name, name, provider, tokenizer, max_prompt_tokens, url, api_key, user_id, enabled_chat_bot, created_at, updated_at)
        VALUES #{rows};
      SQL
    end
  end

  def has_companion_user?(user_id)
    DB.query_single("SELECT id FROM users WHERE id = :user_id", user_id: user_id).first.present?
  end

  def fetch_setting(name)
    DB.query_single(
      "SELECT value FROM site_settings WHERE name = :setting_name",
      setting_name: name,
    ).first
  end

  def claude_bot_id(model)
    case model
    when "claude-2"
      -112
    when "claude-3-haiku"
      -119
    when "claude-3-sonnet"
      -118
    when "claude-instant-1"
      nil
    when "claude-3-opus"
      -117
    end
  end

  def mapped_bedrock_model(model)
    case model
    when "claude-2"
      "anthropic.claude-v2:1"
    when "claude-3-haiku"
      "anthropic.claude-3-haiku-20240307-v1:0"
    when "claude-3-sonnet"
      "anthropic.claude-3-sonnet-20240229-v1:0"
    when "claude-instant-1"
      "anthropic.claude-instant-v1"
    when "claude-3-opus"
      "anthropic.claude-3-opus-20240229-v1:0"
    end
  end

  def display_name(model)
    case model
    when "claude-2"
      "Claude 2"
    when "claude-3-haiku"
      "Claude 3 Haiku"
    when "claude-3-sonnet"
      "Claude 3 Sonnet"
    when "claude-instant-1"
      "Claude Instant 1"
    when "claude-3-opus"
      "Claude 3 Opus"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
