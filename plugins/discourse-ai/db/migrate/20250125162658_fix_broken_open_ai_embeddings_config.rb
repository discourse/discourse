# frozen_string_literal: true

class FixBrokenOpenAiEmbeddingsConfig < ActiveRecord::Migration[7.2]
  def up
    return if fetch_setting("ai_embeddings_selected_model").present?

    return if DB.query_single("SELECT COUNT(*) FROM embedding_definitions").first > 0

    open_ai_models = %w[text-embedding-3-large text-embedding-3-small text-embedding-ada-002]
    current_model = fetch_setting("ai_embeddings_model")
    return if !open_ai_models.include?(current_model)

    endpoint = fetch_setting("ai_openai_embeddings_url") || "https://api.openai.com/v1/embeddings"
    api_key = fetch_setting("ai_openai_api_key")
    return if api_key.blank?

    attrs = {
      display_name: current_model,
      url: endpoint,
      api_key: api_key,
      provider: "open_ai",
    }.merge(model_attrs(current_model))

    persist_config(attrs)
  end

  def fetch_setting(name)
    DB.query_single(
      "SELECT value FROM site_settings WHERE name = :setting_name",
      setting_name: name,
    ).first || ENV["DISCOURSE_#{name&.upcase}"]
  end

  def model_attrs(model_name)
    if model_name == "text-embedding-3-large"
      {
        dimensions: 2000,
        max_sequence_length: 8191,
        id: 7,
        pg_function: "<=>",
        tokenizer_class: "DiscourseAi::Tokenizer::OpenAiTokenizer",
        matryoshka_dimensions: true,
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
      INSERT INTO embedding_definitions (id, display_name, dimensions, max_sequence_length, version, pg_function, provider, tokenizer_class, url, api_key, provider_params, matryoshka_dimensions, created_at, updated_at)
      VALUES (:id, :display_name, :dimensions, :max_sequence_length, 1, :pg_function, :provider, :tokenizer_class, :url, :api_key, :provider_params, :matryoshka_dimensions, :now, :now)
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
      matryoshka_dimensions: !!attrs[:matryoshka_dimensions],
      now: Time.zone.now,
    )

    # We hardcoded the ID to match with already generated embeddings. Let's restart the seq to avoid conflicts.
    DB.exec(
      "ALTER SEQUENCE embedding_definitions_id_seq RESTART WITH :new_seq",
      new_seq: attrs[:id].to_i + 1,
    )

    DB.exec(<<~SQL, new_value: attrs[:id])
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES ('ai_embeddings_selected_model', 3, ':new_value', NOW(), NOW())
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
