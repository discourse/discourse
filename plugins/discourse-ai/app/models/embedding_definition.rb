# frozen_string_literal: true

class EmbeddingDefinition < ActiveRecord::Base
  CLOUDFLARE = "cloudflare"
  HUGGING_FACE = "hugging_face"
  OPEN_AI = "open_ai"
  GOOGLE = "google"
  AWS_BEDROCK = "aws_bedrock"

  class << self
    def provider_names
      [CLOUDFLARE, HUGGING_FACE, OPEN_AI, GOOGLE, AWS_BEDROCK]
    end

    def distance_functions
      %w[<#> <=>]
    end

    def tokenizer_names
      [
        DiscourseAi::Tokenizer::AllMpnetBaseV2Tokenizer,
        DiscourseAi::Tokenizer::BgeLargeEnTokenizer,
        DiscourseAi::Tokenizer::BgeM3Tokenizer,
        DiscourseAi::Tokenizer::GeminiTokenizer,
        DiscourseAi::Tokenizer::MultilingualE5LargeTokenizer,
        DiscourseAi::Tokenizer::OpenAiTokenizer,
        DiscourseAi::Tokenizer::OpenAiCl100kTokenizer,
        DiscourseAi::Tokenizer::MistralTokenizer,
        DiscourseAi::Tokenizer::QwenTokenizer,
      ].map(&:name)
    end

    def provider_params
      {
        open_ai: {
          model_name: :text,
        },
        aws_bedrock: {
          model_id: :text,
          region: :text,
          access_key_id: {
            type: :secret,
            optional: true,
          },
          role_arn: {
            type: :text,
            optional: true,
          },
        },
      }
    end

    def secret_param?(provider, key)
      definition = provider_params.dig(provider&.to_sym, key.to_sym)
      definition == :secret || (definition.is_a?(Hash) && definition[:type] == :secret)
    end

    def presets
      @presets ||= [
        {
          preset_id: "cohere-embed-v4",
          display_name: "Cohere Embed v4 (AWS Bedrock)",
          dimensions: 1536,
          max_sequence_length: 8192,
          pg_function: "<=>",
          tokenizer_class: "DiscourseAi::Tokenizer::OpenAiCl100kTokenizer",
          provider: AWS_BEDROCK,
          matryoshka_dimensions: true,
          provider_params: {
            model_id: "cohere.embed-v4:0",
            region: "us-east-1",
            access_key_id: nil,
            role_arn: nil,
          },
        },
        {
          preset_id: "bge-large-en",
          display_name: "bge-large-en",
          dimensions: 1024,
          max_sequence_length: 512,
          pg_function: "<#>",
          tokenizer_class: "DiscourseAi::Tokenizer::BgeLargeEnTokenizer",
          provider: HUGGING_FACE,
          search_prompt: "Represent this sentence for searching relevant passages:",
        },
        {
          preset_id: "bge-m3",
          display_name: "bge-m3",
          dimensions: 1024,
          max_sequence_length: 8192,
          pg_function: "<#>",
          tokenizer_class: "DiscourseAi::Tokenizer::BgeM3Tokenizer",
          provider: HUGGING_FACE,
        },
        {
          preset_id: "gemini-embedding-001",
          display_name: "Gemini's gemini-embedding-001",
          dimensions: 3072,
          max_sequence_length: 1536,
          pg_function: "<=>",
          url:
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent",
          tokenizer_class: "DiscourseAi::Tokenizer::GeminiTokenizer",
          provider: GOOGLE,
        },
        {
          preset_id: "multilingual-e5-large",
          display_name: "multilingual-e5-large",
          dimensions: 1024,
          max_sequence_length: 512,
          pg_function: "<=>",
          tokenizer_class: "DiscourseAi::Tokenizer::MultilingualE5LargeTokenizer",
          provider: HUGGING_FACE,
        },
        # "text-embedding-3-large" real dimentions are 3072, but we only support up to 2000 in the
        # indexes, so we downsample to 2000 via API.
        {
          preset_id: "text-embedding-3-large",
          display_name: "text-embedding-3-large",
          dimensions: 2000,
          max_sequence_length: 8191,
          pg_function: "<=>",
          tokenizer_class: "DiscourseAi::Tokenizer::OpenAiCl100kTokenizer",
          url: "https://api.openai.com/v1/embeddings",
          provider: OPEN_AI,
          matryoshka_dimensions: true,
          provider_params: {
            model_name: "text-embedding-3-large",
          },
        },
        {
          preset_id: "text-embedding-3-small",
          display_name: "text-embedding-3-small",
          dimensions: 1536,
          max_sequence_length: 8191,
          pg_function: "<=>",
          tokenizer_class: "DiscourseAi::Tokenizer::OpenAiCl100kTokenizer",
          url: "https://api.openai.com/v1/embeddings",
          provider: OPEN_AI,
          matryoshka_dimensions: true,
          provider_params: {
            model_name: "text-embedding-3-small",
          },
        },
        {
          preset_id: "text-embedding-ada-002",
          display_name: "text-embedding-ada-002",
          dimensions: 1536,
          max_sequence_length: 8191,
          pg_function: "<=>",
          tokenizer_class: "DiscourseAi::Tokenizer::OpenAiCl100kTokenizer",
          url: "https://api.openai.com/v1/embeddings",
          provider: OPEN_AI,
          provider_params: {
            model_name: "text-embedding-ada-002",
          },
        },
      ]
    end
  end

  belongs_to :ai_secret, optional: true

  validates :provider, presence: true, inclusion: provider_names
  validates :display_name, presence: true, length: { maximum: 100 }
  validates :tokenizer_class, presence: true, inclusion: tokenizer_names
  validates :dimensions, :max_sequence_length, presence: true
  validates :url, presence: true, unless: :aws_bedrock?
  validates :pg_function, presence: true, inclusion: distance_functions
  validate :api_key_or_secret_present
  validate :bedrock_params_present, if: :aws_bedrock?

  before_validation :assign_bedrock_url, if: :aws_bedrock?

  after_create :create_indexes
  after_update_commit :clear_provider_pause
  after_destroy_commit :clear_provider_pause

  def create_indexes
    Jobs.enqueue(:manage_embedding_def_search_index, id: id)
  end

  def clear_provider_pause
    DiscourseAi::Embeddings::ProviderHealth.clear!(id)
  end

  def tokenizer
    tokenizer_class.constantize
  end

  def inference_client
    case provider
    when CLOUDFLARE
      cloudflare_client
    when HUGGING_FACE
      hugging_face_client
    when OPEN_AI
      open_ai_client
    when GOOGLE
      gemini_client
    when AWS_BEDROCK
      bedrock_client
    else
      raise "Uknown embeddings provider"
    end
  end

  def lookup_custom_param(key)
    value = provider_params&.dig(key)
    return value if value.nil?

    if self.class.secret_param?(provider, key) && value.to_s.match?(/\A\d+\z/)
      return AiSecret.find_by(id: value.to_i)&.secret
    end

    value
  end

  def aws_bedrock?
    provider == AWS_BEDROCK
  end

  def endpoint_url
    return url if !url.starts_with?("srv://")

    service = DiscourseAi::Utils::DnsSrv.lookup(url.sub("srv://", ""))
    "https://#{service.target}:#{service.port}"
  end

  def prepare_query_text(text, asymmetric: false)
    strategy.prepare_query_text(text, self, asymmetric: asymmetric)
  end

  def prepare_target_text(target)
    strategy.prepare_target_text(target, self)
  end

  def strategy_id
    strategy.id
  end

  def strategy_version
    strategy.version
  end

  def api_key
    if seeded?
      env_key = "DISCOURSE_AI_SEEDED_EMBEDDING_API_KEY"
      ENV[env_key] || self[:api_key]
    elsif ai_secret.present?
      ai_secret.secret
    else
      self[:api_key]
    end
  end

  private

  def api_key_or_secret_present
    return if seeded?
    # The AWS SDK can resolve credentials from the environment or instance role.
    return if aws_bedrock?
    if ai_secret_id.present?
      unless AiSecret.exists?(ai_secret_id)
        errors.add(:ai_secret_id, I18n.t("discourse_ai.embeddings.secret_not_found"))
      end
      return
    end
    return if self[:api_key].present?
    errors.add(:base, I18n.t("discourse_ai.embeddings.secret_required"))
  end

  def bedrock_params_present
    %w[model_id region].each do |param|
      next if lookup_custom_param(param).present?
      errors.add(:base, I18n.t("discourse_ai.embeddings.missing_provider_param", param: param))
    end
  end

  # Bedrock requests are addressed by region and model ID, so the URL is only
  # informational, but the column is required.
  def assign_bedrock_url
    region = lookup_custom_param("region")
    self.url = "https://bedrock-runtime.#{region}.amazonaws.com" if region.present?
  end

  def strategy
    @strategy ||= DiscourseAi::Embeddings::Strategies::Truncation.new
  end

  def cloudflare_client
    DiscourseAi::Inference::CloudflareWorkersAi.new(endpoint_url, api_key)
  end

  def hugging_face_client
    DiscourseAi::Inference::HuggingFaceTextEmbeddings.new(endpoint_url, api_key)
  end

  def open_ai_client
    client_dimensions = matryoshka_dimensions ? dimensions : nil

    DiscourseAi::Inference::OpenAiEmbeddings.new(
      endpoint_url,
      api_key,
      lookup_custom_param("model_name"),
      client_dimensions,
    )
  end

  def gemini_client
    client_dimensions = matryoshka_dimensions ? dimensions : nil

    DiscourseAi::Inference::GeminiEmbeddings.new(endpoint_url, api_key, client_dimensions)
  end

  def bedrock_client
    DiscourseAi::Inference::BedrockEmbeddings.new(
      region: lookup_custom_param("region"),
      model_id: lookup_custom_param("model_id"),
      dimensions: matryoshka_dimensions ? dimensions : nil,
      api_key: api_key,
      access_key_id: lookup_custom_param("access_key_id"),
      role_arn: lookup_custom_param("role_arn"),
    )
  end
end

# == Schema Information
#
# Table name: embedding_definitions
#
#  id                    :bigint           not null, primary key
#  api_key               :string
#  dimensions            :integer          not null
#  display_name          :string           not null
#  embed_prompt          :string           default(""), not null
#  matryoshka_dimensions :boolean          default(FALSE), not null
#  max_sequence_length   :integer          not null
#  pg_function           :string           not null
#  provider              :string           not null
#  provider_params       :jsonb
#  search_prompt         :string           default(""), not null
#  seeded                :boolean          default(FALSE), not null
#  tokenizer_class       :string           not null
#  url                   :string           not null
#  version               :integer          default(1), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  ai_secret_id          :bigint
#
# Indexes
#
#  index_embedding_definitions_on_ai_secret_id  (ai_secret_id)
#
