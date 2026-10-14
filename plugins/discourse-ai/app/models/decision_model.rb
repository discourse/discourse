# frozen_string_literal: true

class DecisionModel < ActiveRecord::Base
  PROVIDERS = %w[system_one open_ai].freeze

  belongs_to :ai_secret, optional: true

  validates :display_name, presence: true, length: { maximum: 100 }
  validates :name, presence: true, length: { maximum: 255 }
  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :url, presence: true, length: { maximum: 1000 }
  validate :valid_endpoint_url
  validate :secret_exists

  def self.presets
    @presets ||= [
      {
        preset_id: "jev-latest",
        display_name: "TypeSafe Jev",
        name: "jev-latest",
        url: "https://api.typesafe.ai/v1/systemone",
        provider: "system_one",
        vision_enabled: false,
      }.freeze,
      {
        preset_id: "vllm-sr-d3",
        display_name: "d3",
        name: "vllm-sr/d3",
        url: "",
        provider: "system_one",
        vision_enabled: true,
      }.freeze,
      {
        preset_id: "cloudflare-clef",
        display_name: "Cloudflare Clef",
        name: "clef",
        url: "https://api.cloudflare.com/client/v4/accounts/ACCOUNT_ID/ai/run/@cf/cloudflare/clef",
        provider: "system_one",
        vision_enabled: true,
      }.freeze,
      {
        preset_id: "cloudflare-clef-flash",
        display_name: "Cloudflare Clef Flash",
        name: "clef-flash",
        url:
          "https://api.cloudflare.com/client/v4/accounts/ACCOUNT_ID/ai/run/@cf/cloudflare/clef-flash",
        provider: "system_one",
        vision_enabled: true,
      }.freeze,
      {
        preset_id: "gpt-6-luna",
        display_name: "GPT-6 Luna",
        name: "gpt-6-luna",
        url: "https://api.openai.com/v1/decisions",
        provider: "open_ai",
        vision_enabled: true,
      }.freeze,
    ].freeze
  end

  def decide(state, **)
    DiscourseAi::Decisions::Client.new(self).decide(state, **)
  end

  def api_key
    ai_secret&.secret
  end

  def endpoint_url
    uri = URI(url)
    return url if uri.scheme != "srv"

    service =
      begin
        DiscourseAi::Utils::DnsSrv.lookup(uri.host)
      rescue Resolv::ResolvError, Resolv::ResolvTimeout => e
        raise DiscourseAi::Decisions::RequestFailed,
              "Request failed: SRV lookup for #{uri.host} failed (#{e.class})"
      end
    if !service
      raise DiscourseAi::Decisions::RequestFailed, "Request failed: no SRV record for #{uri.host}"
    end
    "https://#{service.target}:#{service.port}#{uri.path}#{"?#{uri.query}" if uri.query}"
  end

  private

  def valid_endpoint_url
    return if url.blank?
    uri = URI(url)
    # SRV records supply the port, so one in the URL would be silently ignored.
    if !%w[http https srv].include?(uri.scheme) || uri.host.blank? ||
         (uri.scheme == "srv" && uri.port)
      errors.add(:url, I18n.t("discourse_ai.decision_models.invalid_url"))
    end
  rescue URI::InvalidURIError
    errors.add(:url, I18n.t("discourse_ai.decision_models.invalid_url"))
  end

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
#  name           :string(255)      not null
#  provider       :string(50)       not null
#  url            :string(1000)     not null
#  vision_enabled :boolean          default(FALSE), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  ai_secret_id   :bigint
#
# Indexes
#
#  index_decision_models_on_ai_secret_id  (ai_secret_id)
#
