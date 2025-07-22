# frozen_string_literal: true

class EmbeddingConfigDataMigration < ActiveRecord::Migration[7.0]
  def up
    current_model = fetch_setting("ai_embeddings_model") || "bge-large-en"
    provider = provider_for(current_model)

    if provider.present?
      attrs = creds_for(provider)

      if attrs.present?
        attrs = attrs.merge(model_attrs(current_model))
        attrs[:display_name] = current_model
        attrs[:provider] = provider
        persist_config(attrs)
      end
    end
  end

  def down
  end

  # Utils

  def fetch_setting(name)
    DB.query_single(
      "SELECT value FROM site_settings WHERE name = :setting_name",
      setting_name: name,
    ).first || ENV["DISCOURSE_#{name&.upcase}"]
  end

  def provider_for(model)
    cloudflare_api_token = fetch_setting("ai_cloudflare_workers_api_token")

    return "cloudflare" if model == "bge-large-en" && cloudflare_api_token.present?

    tei_models = %w[bge-large-en bge-m3 multilingual-e5-large]
    return "hugging_face" if tei_models.include?(model)

    return "google" if model == "gemini"

    if %w[text-embedding-3-large text-embedding-3-small text-embedding-ada-002].include?(model)
      return "open_ai"
    end

    nil
  end

  def creds_for(provider)
    # CF
    if provider == "cloudflare"
      api_key = fetch_setting("ai_cloudflare_workers_api_token")
      account_id = fetch_setting("ai_cloudflare_workers_account_id")

      return if api_key.blank? || account_id.blank?

      {
        url:
          "https://api.cloudflare.com/client/v4/accounts/#{account_id}/ai/run/@cf/baai/bge-large-en-v1.5",
        api_key: api_key,
      }
      # TEI
    elsif provider == "hugging_face"
      seeded = false
      endpoint = fetch_setting("ai_hugging_face_tei_endpoint")

      if endpoint.blank?
        endpoint = fetch_setting("ai_hugging_face_tei_endpoint_srv")
        if endpoint.present?
          endpoint = "srv://#{endpoint}"
          seeded = true
        end
      end

      api_key = fetch_setting("ai_hugging_face_tei_api_key")

      return if endpoint.blank? || api_key.blank?

      { url: endpoint, api_key: api_key, seeded: seeded }
      # Gemini
    elsif provider == "google"
      api_key = fetch_setting("ai_gemini_api_key")

      return if api_key.blank?

      {
        url: "https://generativelanguage.googleapis.com/v1beta/models/embedding-001:embedContent",
        api_key: api_key,
      }

      # Open AI
    elsif provider == "open_ai"
      endpoint = fetch_setting("ai_openai_embeddings_url") || "https://api.openai.com/v1/embeddings"
      api_key = fetch_setting("ai_openai_api_key")

      return if endpoint.blank? || api_key.blank?

      { url: endpoint, api_key: api_key }
    else
      nil
    end
  end

  def model_attrs(model_name)
    if model_name == "bge-large-en"
      {
        dimensions: 1024,
        max_sequence_length: 512,
        id: 4,
        pg_function: "<#>",
        tokenizer_class: "DiscourseAi::Tokenizer::BgeLargeEnTokenizer",
      }
    elsif model_name == "bge-m3"
      {
        dimensions: 1024,
        max_sequence_length: 8192,
        id: 8,
        pg_function: "<#>",
        tokenizer_class: "DiscourseAi::Tokenizer::BgeM3Tokenizer",
      }
    elsif model_name == "gemini"
      {
        dimensions: 768,
        max_sequence_length: 1536,
        id: 5,
        pg_function: "<=>",
        tokenizer_class: "DiscourseAi::Tokenizer::OpenAiTokenizer",
      }
    elsif model_name == "multilingual-e5-large"
      {
        dimensions: 1024,
        max_sequence_length: 512,
        id: 3,
        pg_function: "<=>",
        tokenizer_class: "DiscourseAi::Tokenizer::MultilingualE5LargeTokenizer",
      }
    elsif model_name == "text-embedding-3-large"
      {
        dimensions: 2000,
        max_sequence_length: 8191,
        id: 7,
        pg_function: "<=>",
        tokenizer_class: "DiscourseAi::Tokenizer::OpenAiTokenizer",
        provider_params: {
          model_name: "text-embedding-3-large",
        },
      }
    elsif model_name == "text-embedding-3-small"
      {
        dimensions: 1536,
        max_sequence_length: 8191,
        id: 6,
        pg_function: "<=>",
        tokenizer_class: "DiscourseAi::Tokenizer::OpenAiTokenizer",
        provider_params: {
          model_name: "text-embedding-3-small",
        },
      }
    else
      {
        dimensions: 1536,
        max_sequence_length: 8191,
        id: 2,
        pg_function: "<=>",
        tokenizer_class: "DiscourseAi::Tokenizer::OpenAiTokenizer",
        provider_params: {
          model_name: "text-embedding-ada-002",
        },
      }
    end
  end

  def persist_config(attrs)
    DB.exec(
      <<~SQL,
      INSERT INTO embedding_definitions (id, display_name, dimensions, max_sequence_length, version, pg_function, provider, tokenizer_class, url, api_key, provider_params, seeded, created_at, updated_at)
      VALUES (:id, :display_name, :dimensions, :max_sequence_length, 1, :pg_function, :provider, :tokenizer_class, :url, :api_key, :provider_params, :seeded, :now, :now)
      SQL
      id: attrs[:id],
      display_name: attrs[:display_name],
      dimensions: attrs[:dimensions],
      max_sequence_length: attrs[:max_sequence_length],
      pg_function: attrs[:pg_function],
      provider: attrs[:provider],
      tokenizer_class: attrs[:tokenizer_class],
      url: attrs[:url],
      api_key: attrs[:api_key],
      provider_params: attrs[:provider_params]&.to_json,
      seeded: !!attrs[:seeded],
      now: Time.zone.now,
    )

    # We hardcoded the ID to match with already generated embeddings. Let's restart the seq to avoid conflicts.
    DB.exec(
      "ALTER SEQUENCE embedding_definitions_id_seq RESTART WITH :new_seq",
      new_seq: attrs[:id].to_i + 1,
    )

    DB.exec(<<~SQL, new_value: attrs[:id])
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES ('ai_embeddings_selected_model', 3, :new_value, NOW(), NOW())
    SQL
  end
end
