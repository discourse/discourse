# frozen_string_literal: true

class DecisionModel < ActiveRecord::Base
  SYSTEM_ONE = "system_one"
  OPEN_AI = "open_ai"

  class << self
    def provider_names
      [SYSTEM_ONE, OPEN_AI]
    end

    def presets
      @presets ||= [
        {
          preset_id: "jev-latest",
          display_name: "Jev",
          name: "jev-latest",
          url: "https://api.typesafe.ai/v1/systemone",
          provider: SYSTEM_ONE,
          vision_enabled: false,
        },
        {
          preset_id: "vllm-sr-d3",
          display_name: "d3",
          name: "vllm-sr/d3",
          url: "",
          provider: SYSTEM_ONE,
          vision_enabled: true,
        },
        {
          preset_id: "gpt-6-luna",
          display_name: "GPT-6 Luna",
          name: "gpt-6-luna",
          url: "https://api.openai.com/v1/decisions",
          provider: OPEN_AI,
          vision_enabled: true,
        },
      ]
    end
  end

  belongs_to :ai_secret, optional: true

  validates :display_name, presence: true, length: { maximum: 100 }
  validates :name, presence: true, length: { maximum: 255 }
  validates :provider, presence: true, inclusion: provider_names
  validates :url, presence: true, length: { maximum: 1000 }
  validate :secret_exists

  # Asks this model typed questions about `state`. See DiscourseAi::Decisions::Client#decide.
  #
  #   result =
  #     decision_model.decide(
  #       post.raw,
  #       questions: [{ type: "yes_no", name: "spam", instructions: "Is this post spam?" }],
  #       feature_name: "spam_detection",
  #       user: post.user,
  #     )
  #   result["spam"].yes?
  def decide(state, **)
    DiscourseAi::Decisions::Client.new(self).decide(state, **)
  end

  def api_key
    ai_secret&.secret
  end

  def endpoint_url
    return url if !url.starts_with?("srv://")

    service = DiscourseAi::Utils::DnsSrv.lookup(url.sub("srv://", ""))
    "https://#{service.target}:#{service.port}"
  end

  private

  # Self-hosted endpoints may run without authentication, so a secret is optional.
  def secret_exists
    return if ai_secret_id.blank? || AiSecret.exists?(ai_secret_id)
    errors.add(:ai_secret_id, I18n.t("discourse_ai.decision_models.secret_not_found"))
  end
end

# == Schema Information
#
# Table name: decision_models
#
#  id             :bigint           not null, primary key
#  display_name   :string(100)      not null
#  name           :string           not null
#  provider       :string           not null
#  url            :string           not null
#  vision_enabled :boolean          default(FALSE), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  ai_secret_id   :bigint
#
# Indexes
#
#  index_decision_models_on_ai_secret_id  (ai_secret_id)
#
