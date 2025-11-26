# frozen_string_literal: true

class LlmModel < ActiveRecord::Base
  FIRST_BOT_USER_ID = -1200
  BEDROCK_PROVIDER_NAME = "aws_bedrock"

  has_many :llm_quotas, dependent: :destroy
  has_one :llm_credit_allocation, dependent: :destroy
  has_many :llm_feature_credit_costs, dependent: :destroy
  belongs_to :user

  validates :display_name, presence: true, length: { maximum: 100 }
  validates :tokenizer, presence: true, inclusion: DiscourseAi::Completions::Llm.tokenizer_names
  validates :provider, presence: true, inclusion: DiscourseAi::Completions::Llm.provider_names
  validates :url, presence: true, unless: -> { provider == BEDROCK_PROVIDER_NAME }
  validates :name, :api_key, presence: true
  validates :max_prompt_tokens, numericality: { greater_than: 0 }
  validates :input_cost,
            :cached_input_cost,
            :cache_write_cost,
            :output_cost,
            :max_output_tokens,
            numericality: {
              greater_than_or_equal_to: 0,
            },
            allow_nil: true
  validate :required_provider_params
  scope :in_use,
        -> do
          model_ids = DiscourseAi::Configuration::LlmEnumerator.global_usage.keys
          where(id: model_ids)
        end

  def self.provider_params
    {
      aws_bedrock: {
        access_key_id: :text,
        role_arn: :text,
        region: :text,
        disable_native_tools: :checkbox,
        disable_temperature: :checkbox,
        disable_top_p: :checkbox,
        enable_reasoning: :checkbox,
        reasoning_tokens: :number,
        prompt_caching: {
          type: :enum,
          values: %w[never tool_results always],
          default: "never",
        },
        effort: {
          type: :enum,
          values: %w[default low medium high],
          default: "default",
        },
      },
      anthropic: {
        disable_native_tools: :checkbox,
        disable_temperature: :checkbox,
        disable_top_p: :checkbox,
        enable_reasoning: :checkbox,
        reasoning_tokens: :number,
        prompt_caching: {
          type: :enum,
          values: %w[never tool_results always],
          default: "never",
        },
        effort: {
          type: :enum,
          values: %w[default low medium high],
          default: "default",
        },
      },
      open_ai: {
        organization: :text,
        disable_native_tools: :checkbox,
        disable_temperature: :checkbox,
        disable_top_p: :checkbox,
        disable_streaming: :checkbox,
        enable_responses_api: :checkbox,
        reasoning_effort: {
          type: :enum,
          values: %w[default minimal low medium high],
          default: "default",
        },
      },
      groq: {
        disable_native_tools: :checkbox,
        disable_temperature: :checkbox,
        disable_top_p: :checkbox,
        disable_streaming: :checkbox,
        reasoning_effort: {
          type: :enum,
          values: %w[default minimal low medium high],
          default: "default",
        },
      },
      mistral: {
        disable_native_tools: :checkbox,
      },
      google: {
        disable_native_tools: :checkbox,
        enable_thinking: :checkbox,
        disable_temperature: :checkbox,
        disable_top_p: :checkbox,
        thinking_tokens: :number,
      },
      azure: {
        disable_native_tools: :checkbox,
        enable_responses_api: :checkbox,
        reasoning_effort: {
          type: :enum,
          values: %w[default minimal low medium high],
          default: "default",
        },
      },
      hugging_face: {
        disable_system_prompt: :checkbox,
      },
      vllm: {
        disable_system_prompt: :checkbox,
      },
      ollama: {
        disable_system_prompt: :checkbox,
        enable_native_tool: :checkbox,
        disable_streaming: :checkbox,
      },
      open_router: {
        disable_native_tools: :checkbox,
        provider_order: :text,
        provider_quantizations: :text,
        disable_streaming: :checkbox,
        disable_temperature: :checkbox,
        disable_top_p: :checkbox,
      },
    }
  end

  def to_llm
    DiscourseAi::Completions::Llm.proxy(self)
  end

  def identifier
    "#{id}"
  end

  def toggle_companion_user
    return if name == "fake" && Rails.env.production?

    enable_check = SiteSetting.ai_bot_enabled && enabled_chat_bot

    if enable_check
      if !user
        next_id = DB.query_single(<<~SQL).first
          SELECT min(id) - 1 FROM users
        SQL

        new_user =
          User.new(
            id: [FIRST_BOT_USER_ID, next_id].min,
            email: "no_email_#{SecureRandom.hex}",
            name: name.titleize,
            username: UserNameSuggester.suggest(name),
            active: true,
            approved: true,
            admin: true,
            moderator: true,
            trust_level: TrustLevel[4],
          )
        new_user.save!(validate: false)
        self.update!(user: new_user)
      else
        user.active = true
        user.save!(validate: false)
      end
    elsif user
      # will include deleted
      has_posts = DB.query_single("SELECT 1 FROM posts WHERE user_id = #{user.id} LIMIT 1").present?

      if has_posts
        user.update!(active: false) if user.active
      else
        user.destroy!
        self.update!(user: nil)
      end
    end
  end

  def tokenizer_class
    tokenizer.constantize
  end

  def lookup_custom_param(key)
    provider_params&.dig(key)
  end

  def seeded?
    id.present? && id < 0
  end

  def api_key
    if seeded?
      env_key = "DISCOURSE_AI_SEEDED_LLM_API_KEY_#{id.abs}"
      ENV[env_key] || self[:api_key]
    else
      self[:api_key]
    end
  end

  def credit_system_enabled?
    seeded? && llm_credit_allocation.present?
  end

  def aws_bedrock_credentials
    return nil unless provider == BEDROCK_PROVIDER_NAME

    role_arn = lookup_custom_param("role_arn")
    return nil if role_arn.blank?

    # Invalidate cache if role_arn changed
    if @cached_role_arn != role_arn
      @cached_role_arn = role_arn
      @aws_bedrock_credentials = nil
    end

    @aws_bedrock_credentials ||=
      begin
        require "aws-sdk-sts" unless defined?(Aws::STS)
        region = lookup_custom_param("region")

        Aws::AssumeRoleCredentials.new(
          role_arn: role_arn,
          role_session_name: "discourse-bedrock-#{Process.pid}",
          client: Aws::STS::Client.new(region: region),
        )
      end
  end

  private

  def required_provider_params
    return if provider != BEDROCK_PROVIDER_NAME

    # Region is always required
    if lookup_custom_param("region").blank?
      errors.add(:base, I18n.t("discourse_ai.llm_models.missing_provider_param", param: "region"))
    end

    # Either access_key_id or role_arn must be present
    if lookup_custom_param("access_key_id").blank? && lookup_custom_param("role_arn").blank?
      errors.add(:base, I18n.t("discourse_ai.llm_models.bedrock_missing_auth"))
    end
  end
end

# == Schema Information
#
# Table name: llm_models
#
#  id                :bigint           not null, primary key
#  api_key           :string
#  cache_write_cost  :float            default(0.0)
#  cached_input_cost :float
#  display_name      :string
#  enabled_chat_bot  :boolean          default(FALSE), not null
#  input_cost        :float
#  max_output_tokens :integer
#  max_prompt_tokens :integer          not null
#  name              :string           not null
#  output_cost       :float
#  provider          :string           not null
#  provider_params   :jsonb
#  tokenizer         :string           not null
#  url               :string
#  vision_enabled    :boolean          default(FALSE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  user_id           :integer
#
