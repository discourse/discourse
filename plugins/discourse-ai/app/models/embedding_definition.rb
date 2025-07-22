# frozen_string_literal: true

class EmbeddingDefinition < ActiveRecord::Base
  CLOUDFLARE = "cloudflare"
  HUGGING_FACE = "hugging_face"
  OPEN_AI = "open_ai"
  GOOGLE = "google"

  class << self
    def provider_names
      [CLOUDFLARE, HUGGING_FACE, OPEN_AI, GOOGLE]
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
      { open_ai: { model_name: :text } }
    end

    def presets
      @presets ||=
        begin
          [
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
              display_name: "Gemini's embedding-001",
              dimensions: 768,
              max_sequence_length: 1536,
              pg_function: "<=>",
              url:
                "https://generativelanguage.googleapis.com/v1beta/models/embedding-001:embedContent",
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
  end

  validates :provider, presence: true, inclusion: provider_names
  validates :display_name, presence: true, length: { maximum: 100 }
  validates :tokenizer_class, presence: true, inclusion: tokenizer_names
  validates_presence_of :url, :api_key, :dimensions, :max_sequence_length, :pg_function

  after_create :create_indexes

  def create_indexes
    Jobs.enqueue(:manage_embedding_def_search_index, id: self.id)
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
    else
      raise "Uknown embeddings provider"
    end
  end

  def lookup_custom_param(key)
    provider_params&.dig(key)
  end

  def endpoint_url
    return url if !url.starts_with?("srv://")

    service = DiscourseAi::Utils::DnsSrv.lookup(url.sub("srv://", ""))
    "https://#{service.target}:#{service.port}"
  end

  def prepare_query_text(text, asymetric: false)
    strategy.prepare_query_text(text, self, asymetric: asymetric)
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
    else
      self[:api_key]
    end
  end

  private

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
    DiscourseAi::Inference::GeminiEmbeddings.new(endpoint_url, api_key)
  end
end

# == Schema Information
#
# Table name: embedding_definitions
#
#  id                    :bigint           not null, primary key
#  display_name          :string           not null
#  dimensions            :integer          not null
#  max_sequence_length   :integer          not null
#  version               :integer          default(1), not null
#  pg_function           :string           not null
#  provider              :string           not null
#  tokenizer_class       :string           not null
#  url                   :string           not null
#  api_key               :string
#  seeded                :boolean          default(FALSE), not null
#  provider_params       :jsonb
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  embed_prompt          :string           default(""), not null
#  search_prompt         :string           default(""), not null
#  matryoshka_dimensions :boolean          default(FALSE), not null
#
