# frozen_string_literal: true

class DecisionModel < ActiveRecord::Base
  PROVIDERS = %w[system_one typesafe open_ai].freeze
  MAX_CUSTOM_HEADERS = 20
  MAX_CUSTOM_HEADER_NAME_LENGTH = 128
  MAX_CUSTOM_HEADER_VALUE_LENGTH = 4000
  CUSTOM_HEADER_LIMITS = {
    count: MAX_CUSTOM_HEADERS,
    name_length: MAX_CUSTOM_HEADER_NAME_LENGTH,
    value_length: MAX_CUSTOM_HEADER_VALUE_LENGTH,
  }.freeze
  CUSTOM_HEADER_NAME = /\A[!\#$%&'*+\-.^_`|~0-9A-Za-z]+\z/
  CUSTOM_HEADER_VALUE = /\A[\x20-\x7E]*\z/
  RESERVED_CUSTOM_HEADERS = %w[
    authorization
    content-type
    host
    content-length
    transfer-encoding
    connection
    cookie
    cookie2
    set-cookie
    proxy-authorization
    proxy-authenticate
    proxy-connection
    www-authenticate
    keep-alive
    te
    trailer
    upgrade
    expect
    accept-encoding
    content-encoding
  ].freeze

  belongs_to :ai_secret, optional: true
  has_one :decision_model_credit_allocation, dependent: :destroy
  has_many :decision_model_feature_credit_costs, dependent: :destroy
  has_many :decision_model_credit_daily_usages, dependent: :delete_all

  validates :display_name, presence: true, length: { maximum: 100 }
  validates :name, presence: true, length: { maximum: 255 }
  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :url, presence: true, length: { maximum: 1000 }
  validate :valid_endpoint_url
  validate :secret_exists
  validate :valid_custom_headers

  def self.presets
    @presets ||= [
      {
        preset_id: "jev-latest",
        display_name: "TypeSafe Jev",
        name: "jev-latest",
        url: "https://api.typesafe.ai/v1/systemone",
        provider: "typesafe",
        vision_enabled: false,
      }.freeze,
      {
        preset_id: "jev-latest-vision",
        display_name: "TypeSafe Jev with images (experimental)",
        name: "jev-latest",
        url: "https://api.typesafe.ai/v1/systemone",
        provider: "typesafe",
        vision_enabled: true,
        custom_headers: [{ name: "TypeSafe-Danger-Zone-Images", value: "true" }.freeze].freeze,
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

  def seeded?
    id.present? && id < 0
  end

  def api_key
    if seeded?
      ENV["DISCOURSE_AI_SEEDED_DECISION_MODEL_API_KEY_#{id.abs}"] || self[:api_key]
    else
      ai_secret&.secret
    end
  end

  def credit_system_enabled?
    seeded? && decision_model_credit_allocation.present?
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

  def supports_custom_headers?
    %w[system_one typesafe].include?(provider)
  end

  def custom_headers_for_request
    # Stored configuration can bypass validations, so check it again before transport.
    return {} if !supports_custom_headers? || custom_headers_error

    custom_headers.to_h { |header| [header["name"], header["value"]] }
  end

  private

  def valid_custom_headers
    error = custom_headers_error
    if error
      errors.add(
        :custom_headers,
        I18n.t("discourse_ai.decision_models.custom_headers.#{error}", **CUSTOM_HEADER_LIMITS),
      )
    end
  end

  def custom_headers_error
    return :invalid_format if !custom_headers.is_a?(Array)
    return :too_many if custom_headers.size > MAX_CUSTOM_HEADERS
    return :unsupported_provider if custom_headers.present? && !supports_custom_headers?

    names = Set.new
    custom_headers.each do |header|
      return :invalid_format if !header.is_a?(Hash) || header.keys.sort != %w[name value]
      name, value = header.values_at("name", "value")
      if !name.is_a?(String) || name.length > MAX_CUSTOM_HEADER_NAME_LENGTH ||
           !CUSTOM_HEADER_NAME.match?(name)
        return :invalid_name
      end
      if !value.is_a?(String) || value.length > MAX_CUSTOM_HEADER_VALUE_LENGTH ||
           !CUSTOM_HEADER_VALUE.match?(value)
        return :invalid_value
      end
      return :reserved_name if RESERVED_CUSTOM_HEADERS.include?(name.downcase)
      return :duplicate_name if !names.add?(name.downcase)
    end

    nil
  end

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
#  api_key        :string
#  custom_headers :jsonb            not null
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
