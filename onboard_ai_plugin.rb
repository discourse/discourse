# frozen_string_literal: true

# AI Plugin Onboarding Script
#
# This script configures the discourse-ai plugin with:
# 1. An LLM Model (for AI completions and chat)
# 2. An Embeddings Definition (for semantic search)
# 3. Sentiment analysis configuration
# 4. Enables all AI features
#
# Usage:
#   bundle exec rails runner onboard_ai_plugin.rb
#

module DiscourseAi
  class OnboardingScript
    # Auth with Snorlax
    # If you don't have a functional 1password CLI setup, replace this with your API key directly.
    # Search for "Snorlax LLM" in your 1password vault to find the API key.
    api_key =
      `op item get 'Snorlax LLM' --account discourse.1password.com --fields label=credential --reveal`.chomp

    LLM_CONFIG = {
      display_name: "CDCK Hosted Model",
      name: "CDCK/MoM",
      provider: "vllm",
      tokenizer: "DiscourseAi::Tokenizer::QwenTokenizer",
      url: "srv://_jolteon._tcp.ai.snorlax.discourse.com",
      max_prompt_tokens: 100_000,
      max_output_tokens: 32_000,
      vision_enabled: true,
      api_key: api_key,
    }

    EMBEDDING_CONFIG = {
      display_name: "CDCK's Qwen3-Embedding-0.6B",
      provider: "hugging_face",
      tokenizer_class: "DiscourseAi::Tokenizer::QwenTokenizer",
      url: "srv://_tei-qwen3._tcp.ai.snorlax.discourse.com",
      dimensions: 1024,
      max_sequence_length: 32_000,
      pg_function: "<=>",
      search_prompt:
        "Instruct: Given a web search query, retrieve relevamt passages that answer the query\nQuery:",
      api_key: api_key,
    }

    SENTIMENT_CONFIG = [
      {
        model_name: "SamLowe/roberta-base-go_emotions",
        endpoint: "srv://_tei-samlowe-emotion._tcp.ai.snorlax.discourse.com",
        api_key: api_key,
      },
      {
        model_name: "cardiffnlp/twitter-roberta-base-sentiment-latest",
        endpoint: "srv://_tei-cardiffnlp-sentiment._tcp.ai.snorlax.discourse.com",
        api_key: api_key,
      },
    ]

    # Feature settings to enable
    FEATURE_SETTINGS = {
      # Master switches
      discourse_ai_enabled: true,
      # Core features
      ai_embeddings_enabled: true,
      ai_embeddings_semantic_search_enabled: true,
      ai_embeddings_semantic_related_topics_enabled: true,
      ai_embeddings_semantic_quick_search_enabled: true,
      ai_helper_enabled: true,
      ai_summarization_enabled: true,
      ai_bot_enabled: true,
      ai_spam_detection_enabled: true,
      ai_translation_enabled: true,
      ai_sentiment_enabled: true,
      ai_summary_gists_enabled: true,
      ai_discover_enabled: true,
    }.freeze

    def self.run
      new.run
    end

    def run
      puts "=" * 80
      puts "AI Plugin Onboarding Script"
      puts "=" * 80
      puts

      ActiveRecord::Base.transaction do
        create_llm_model
        create_embedding_definition
        configure_sentiment_analysis
        set_default_models
        enable_features
        print_summary
      end

      puts
      puts "=" * 80
      puts "Onboarding Complete!"
      puts "=" * 80
    end

    private

    def create_llm_model
      puts "1. Creating LLM Model..."

      @llm_model = LlmModel.create!(LLM_CONFIG)

      puts "   ✓ Created LlmModel: #{@llm_model.display_name} (ID: #{@llm_model.id})"
      puts "     Provider: #{@llm_model.provider}"
      puts "     URL: #{@llm_model.url}"
      puts "     Max tokens: #{@llm_model.max_prompt_tokens}"
    rescue ActiveRecord::RecordInvalid => e
      puts "   ✗ Failed to create LLM Model: #{e.message}"
      raise
    end

    def create_embedding_definition
      puts
      puts "2. Creating Embedding Definition..."

      @embedding_def = EmbeddingDefinition.create!(EMBEDDING_CONFIG)

      puts "   ✓ Created EmbeddingDefinition: #{@embedding_def.display_name} (ID: #{@embedding_def.id})"
      puts "     Provider: #{@embedding_def.provider}"
      puts "     Dimensions: #{@embedding_def.dimensions}"
      puts "     Max sequence: #{@embedding_def.max_sequence_length}"
    rescue ActiveRecord::RecordInvalid => e
      puts "   ✗ Failed to create Embedding Definition: #{e.message}"
      raise
    end

    def configure_sentiment_analysis
      puts
      puts "3. Configuring Sentiment Analysis..."

      SiteSetting.ai_sentiment_model_configs = SENTIMENT_CONFIG.to_json

      puts "   ✓ Configured sentiment models: #{SENTIMENT_CONFIG.length} model(s)"
      puts "     Model: #{SENTIMENT_CONFIG.first[:model_name]}"
    rescue StandardError => e
      puts "   ✗ Failed to configure sentiment: #{e.message}"
      raise
    end

    def set_default_models
      puts
      puts "4. Setting created models as defaults..."

      SiteSetting.ai_default_llm_model = @llm_model.id
      SiteSetting.ai_embeddings_selected_model = @embedding_def.id

      # Enable this LLM as a chat bot via the ai_bot_enabled_llms setting
      existing = SiteSetting.ai_bot_enabled_llms.to_s
      llm_ids = existing.split("|").map(&:to_i).reject(&:zero?)
      llm_ids << @llm_model.id if llm_ids.exclude?(@llm_model.id)
      SiteSetting.ai_bot_enabled_llms = llm_ids.join("|")

      puts "   ✓ Set default LLM: #{@llm_model.display_name}"
      puts "   ✓ Set default embedding model: #{@embedding_def.display_name}"
      puts "   ✓ Enabled LLM as chat bot"

      spam_setting = AiModerationSetting.find_by(setting_type: "spam")
      if spam_setting.blank?
        AiModerationSetting.create!(setting_type: :spam, llm_model_id: @llm_model.id)
      else
        spam_setting.update!(llm_model_id: @llm_model.id)
      end

      puts "   ✓ Configured spam moderation"
    end

    def enable_features
      puts
      puts "5. Enabling AI Features..."

      FEATURE_SETTINGS.each do |setting_name, value|
        SiteSetting.set(setting_name, value)
        puts "   ✓ #{setting_name}: #{value}"
      rescue Discourse::InvalidParameters => e
        puts "   ⚠ Skipping #{setting_name}: #{e.message}"
      end
    end

    def print_summary
      puts
      puts "=" * 80
      puts "Configuration Summary"
      puts "=" * 80
      puts
      puts "LLM Model:"
      puts "  - ID: #{@llm_model.id}"
      puts "  - Name: #{@llm_model.name}"
      puts "  - Display: #{@llm_model.display_name}"
      puts "  - Provider: #{@llm_model.provider}"
      puts "  - Chat Bot: #{@llm_model.enabled_chat_bot? ? "Yes" : "No"}"
      puts
      puts "Embedding Definition:"
      puts "  - ID: #{@embedding_def.id}"
      puts "  - Display: #{@embedding_def.display_name}"
      puts "  - Provider: #{@embedding_def.provider}"
      puts "  - Dimensions: #{@embedding_def.dimensions}"
      puts
      puts "Sentiment Analysis:"
      puts "  - Configured: Yes"
      puts "  - Models: #{SENTIMENT_CONFIG.length}"
      puts
      puts "Enabled Features:"
      enabled_features =
        FEATURE_SETTINGS.select { |k, v| k.to_s.end_with?("_enabled") && v == true }
      enabled_features.each { |feature, _| puts "  - #{feature}" }
      puts
      puts "In case of failure, report at https://dev.discourse.org/t/discourse-ai-dev-env-guide/122453"
      puts
    end
  end
end

# Run the script
DiscourseAi::OnboardingScript.run
