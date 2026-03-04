# frozen_string_literal: true

class MigrateExistingSecretsToAiSecrets < ActiveRecord::Migration[7.0]
  def up
    used_names = {}

    # Helper to generate unique names
    unique_name =
      lambda do |base|
        if !used_names[base]
          used_names[base] = 1
          base
        else
          used_names[base] += 1
          "#{base} (#{used_names[base]})"
        end
      end

    # Collect non-seeded LLM secrets grouped by (api_key, provider)
    llm_rows = DB.query(<<~SQL)
        SELECT id, api_key, provider, provider_params
        FROM llm_models
        WHERE id > 0
          AND api_key IS NOT NULL
          AND api_key != ''
      SQL

    # Collect non-seeded embedding secrets grouped by (api_key, provider)
    embedding_rows = DB.query(<<~SQL)
        SELECT id, api_key, provider
        FROM embedding_definitions
        WHERE (seeded IS NULL OR seeded = false)
          AND api_key IS NOT NULL
          AND api_key != ''
      SQL

    # Build dedup map: (secret_value, provider) -> ai_secret_id
    secret_map = {}

    provider_display = {
      "open_ai" => "OpenAI",
      "anthropic" => "Anthropic",
      "aws_bedrock" => "AWS Bedrock",
      "google" => "Google",
      "hugging_face" => "Hugging Face",
      "azure" => "Azure",
      "ollama" => "Ollama",
      "vllm" => "vLLM",
      "cohere" => "Cohere",
      "open_router" => "Open Router",
      "mistral" => "Mistral",
      "groq" => "Groq",
      "samba_nova" => "SambaNova",
      "cloudflare" => "Cloudflare",
    }

    (llm_rows + embedding_rows).each do |row|
      key = [row.api_key, row.provider]
      next if secret_map[key]

      display_provider = provider_display[row.provider] || row.provider&.titleize || "Unknown"
      name = unique_name.call("#{display_provider} API Key")

      ai_secret_id = DB.query_single(<<~SQL, name: name, secret: row.api_key).first
          INSERT INTO ai_secrets (name, secret, created_at, updated_at)
          VALUES (:name, :secret, NOW(), NOW())
          RETURNING id
        SQL

      secret_map[key] = ai_secret_id
    end

    # Update llm_models with ai_secret_id
    llm_rows.each do |row|
      ai_secret_id = secret_map[[row.api_key, row.provider]]
      DB.exec(<<~SQL, ai_secret_id: ai_secret_id, id: row.id) if ai_secret_id
        UPDATE llm_models SET ai_secret_id = :ai_secret_id WHERE id = :id
      SQL
    end

    # Update embedding_definitions with ai_secret_id
    embedding_rows.each do |row|
      ai_secret_id = secret_map[[row.api_key, row.provider]]
      DB.exec(<<~SQL, ai_secret_id: ai_secret_id, id: row.id) if ai_secret_id
        UPDATE embedding_definitions SET ai_secret_id = :ai_secret_id WHERE id = :id
      SQL
    end

    # Handle Bedrock access_key_id in provider_params
    bedrock_rows = DB.query(<<~SQL)
        SELECT id, provider_params
        FROM llm_models
        WHERE id > 0
          AND provider = 'aws_bedrock'
          AND provider_params IS NOT NULL
      SQL

    bedrock_rows.each do |row|
      params =
        begin
          JSON.parse(row.provider_params)
        rescue StandardError
          next
        end
      access_key = params["access_key_id"]
      next if access_key.blank? || access_key.to_s =~ /\A\d+\z/

      # Create a secret for the access key
      truncated = access_key.length > 4 ? access_key[0..3] + "..." : access_key
      name = unique_name.call("AWS Access Key (#{truncated})")

      ai_secret_id = DB.query_single(<<~SQL, name: name, secret: access_key).first
          INSERT INTO ai_secrets (name, secret, created_at, updated_at)
          VALUES (:name, :secret, NOW(), NOW())
          RETURNING id
        SQL

      params["access_key_id"] = ai_secret_id.to_s
      DB.exec(<<~SQL, params: params.to_json, id: row.id)
        UPDATE llm_models SET provider_params = :params::jsonb WHERE id = :id
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
