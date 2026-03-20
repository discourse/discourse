# frozen_string_literal: true

class AiMcpServer < ActiveRecord::Base
  MAX_TIMEOUT_SECONDS = 300
  AUTH_TYPES = %w[none header_secret oauth].freeze
  HEALTH_STATUSES = %w[unknown healthy error].freeze
  OAUTH_CLIENT_REGISTRATIONS = %w[client_metadata_document manual].freeze
  OAUTH_STATUSES = %w[disconnected connected refresh_failed error].freeze
  OAUTH_REAUTH_TRIGGER_FIELDS = %w[
    url
    oauth_client_registration
    oauth_client_id
    oauth_client_secret_ai_secret_id
    oauth_scopes
  ].freeze

  belongs_to :ai_secret, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :oauth_client_secret,
             class_name: "AiSecret",
             foreign_key: :oauth_client_secret_ai_secret_id,
             optional: true

  has_many :ai_agent_mcp_servers, dependent: :destroy
  has_many :ai_agents, through: :ai_agent_mcp_servers
  has_one :oauth_token,
          class_name: "AiMcpOauthToken",
          dependent: :destroy,
          inverse_of: :ai_mcp_server

  before_validation :normalize_auth_configuration

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :description, presence: true, length: { maximum: 1000 }
  validates :url, presence: true, length: { maximum: 1000 }
  validates :auth_header, presence: true, length: { maximum: 100 }, if: :header_secret?
  validates :auth_scheme, length: { maximum: 100 }
  validates :auth_type, inclusion: { in: AUTH_TYPES }
  validates :oauth_client_registration, inclusion: { in: OAUTH_CLIENT_REGISTRATIONS }, if: :oauth?
  validates :oauth_status, inclusion: { in: OAUTH_STATUSES }, allow_blank: true
  validates :timeout_seconds,
            numericality: {
              only_integer: true,
              greater_than: 0,
              less_than_or_equal_to: MAX_TIMEOUT_SECONDS,
            }
  validates :last_health_status, inclusion: { in: HEALTH_STATUSES }, allow_blank: true

  validate :validate_ai_secret_id_exists
  validate :validate_oauth_client_secret_id_exists
  validate :validate_oauth_configuration
  validate :validate_public_https_url

  after_commit :flush_tool_cache
  after_commit :clear_oauth_tokens_if_auth_type_changed
  after_commit :clear_oauth_credentials_if_configuration_changed
  after_destroy_commit :clear_oauth_tokens

  def auth_header_value
    if oauth?
      token = oauth_token_store.access_token
      return nil if token.blank?

      token_type = oauth_token_type.presence || "Bearer"
      return "#{token_type} #{token}"
    end

    return nil if ai_secret.blank?

    secret = ai_secret.secret
    return secret if auth_scheme.blank?

    "#{auth_scheme} #{secret}"
  end

  def healthy?
    last_health_status == "healthy"
  end

  def tool_definitions
    DiscourseAi::Mcp::ToolRegistry.tool_definitions_for(self)
  end

  def tools_for_serialization
    return @tools_for_serialization if instance_variable_defined?(:@tools_for_serialization)

    @tools_for_serialization =
      tool_definitions.filter_map do |definition|
        tool_name = definition["name"].to_s
        next if tool_name.blank?

        signature =
          DiscourseAi::Agents::Tools::Mcp.class_instance(id, tool_name, definition).signature

        {
          name: tool_name,
          title:
            definition["title"].presence || definition.dig("annotations", "title").presence ||
              tool_name.humanize,
          description: definition["description"].presence || signature[:description],
          parameters: signature[:parameters],
          token_count: DiscourseAi::Tokenizer::OpenAiCl100kTokenizer.size(signature.to_json),
        }
      end
  rescue StandardError
    @tools_for_serialization = []
  end

  def tool_count
    tools_for_serialization.length
  end

  def token_count
    tools_for_serialization.sum { |tool| tool[:token_count].to_i }
  end

  def refresh_tools!(raise_on_error: true)
    if instance_variable_defined?(:@tools_for_serialization)
      remove_instance_variable(:@tools_for_serialization)
    end
    DiscourseAi::Mcp::ToolRegistry.refresh!(self, raise_on_error: raise_on_error)
  end

  def none_auth?
    auth_type == "none"
  end

  def header_secret?
    auth_type == "header_secret"
  end

  def oauth?
    auth_type == "oauth"
  end

  def oauth_connected?
    oauth? && oauth_status == "connected" && oauth_token_store.access_token.present?
  end

  def oauth_needs_refresh?
    oauth_access_token_expires_at.present? && oauth_access_token_expires_at <= 1.minute.from_now
  end

  def oauth_callback_url
    "#{Discourse.base_url}/admin/plugins/discourse-ai/ai-mcp-servers/oauth/callback"
  end

  def oauth_client_metadata_url
    "#{Discourse.base_url}/discourse-ai/mcp/oauth/client-metadata"
  end

  def admin_edit_url
    "#{Discourse.base_url}/admin/plugins/discourse-ai/ai-tools/mcp-servers/#{id}/edit"
  end

  def effective_oauth_client_id
    if oauth_client_registration == "manual"
      oauth_client_id.presence
    else
      oauth_client_metadata_url
    end
  end

  def oauth_client_secret_value
    oauth_client_secret&.secret
  end

  def oauth_discovery_result
    return if oauth_authorization_endpoint.blank? || oauth_token_endpoint.blank?

    DiscourseAi::Mcp::OAuthDiscovery::Result.new(
      resource: url,
      resource_metadata_url: oauth_resource_metadata_url,
      issuer: oauth_issuer,
      authorization_endpoint: oauth_authorization_endpoint,
      token_endpoint: oauth_token_endpoint,
      revocation_endpoint: oauth_revocation_endpoint,
    )
  end

  def store_oauth_discovery!(discovery)
    update_columns(
      oauth_authorization_endpoint: discovery.authorization_endpoint,
      oauth_token_endpoint: discovery.token_endpoint,
      oauth_revocation_endpoint: discovery.revocation_endpoint,
      oauth_issuer: discovery.issuer,
      oauth_resource_metadata_url: discovery.resource_metadata_url,
      oauth_last_error: nil,
    )
  end

  def update_oauth_tokens!(access_token:, refresh_token:, token_type:, expires_in:, granted_scopes:)
    oauth_token_store.write!(access_token: access_token, refresh_token: refresh_token)

    update_columns(
      oauth_status: "connected",
      oauth_token_type: token_type.presence || "Bearer",
      oauth_access_token_expires_at:
        expires_in.present? ? Time.zone.now + expires_in.to_i.seconds : nil,
      oauth_granted_scopes: granted_scopes.presence || oauth_granted_scopes,
      oauth_last_authorized_at: oauth_last_authorized_at || Time.zone.now,
      oauth_last_refreshed_at: Time.zone.now,
      oauth_last_error: nil,
    )
  end

  def mark_oauth_authorized!
    update_columns(
      oauth_status: "connected",
      oauth_last_authorized_at: Time.zone.now,
      oauth_last_refreshed_at: Time.zone.now,
      oauth_last_error: nil,
    )
  end

  def mark_oauth_refresh_failed!(message)
    update_columns(oauth_status: "refresh_failed", oauth_last_error: message.to_s.truncate(1000))
  end

  def mark_oauth_error!(message)
    update_columns(oauth_status: "error", oauth_last_error: message.to_s.truncate(1000))
  end

  def clear_oauth_credentials!
    oauth_token_store.clear!
    update_columns(
      oauth_status: "disconnected",
      oauth_token_type: nil,
      oauth_access_token_expires_at: nil,
      oauth_granted_scopes: nil,
      oauth_authorization_endpoint: nil,
      oauth_token_endpoint: nil,
      oauth_revocation_endpoint: nil,
      oauth_issuer: nil,
      oauth_resource_metadata_url: nil,
      oauth_last_error: nil,
      oauth_last_authorized_at: nil,
      oauth_last_refreshed_at: nil,
    )
  end

  def oauth_token_store
    @oauth_token_store ||= DiscourseAi::Mcp::OAuthTokenStore.new(self)
  end

  def self.public_https_url?(raw_url)
    uri = parse_public_uri(raw_url)
    return false if uri.nil?

    validate_hostname_public!(uri.hostname)
    true
  rescue FinalDestination::SSRFError, SocketError, URI::InvalidURIError
    false
  end

  def self.parse_public_uri(raw_url)
    uri = URI.parse(raw_url.to_s.strip)
    return nil if uri.scheme != "https"
    return nil if uri.host.blank?
    return nil if uri.user.present? || uri.password.present?

    uri
  rescue URI::InvalidURIError
    nil
  end

  def self.validate_hostname_public!(hostname)
    normalized = hostname.to_s.downcase
    raise FinalDestination::SSRFError, "hostname missing" if normalized.blank?
    raise FinalDestination::SSRFError, "localhost is not allowed" if normalized == "localhost"

    ip = IPAddr.new(normalized)
    if !FinalDestination::SSRFDetector.ip_allowed?(ip)
      raise FinalDestination::SSRFError, "private IP is not allowed"
    end
  rescue IPAddr::InvalidAddressError
    FinalDestination::SSRFDetector.lookup_and_filter_ips(normalized)
  end

  private

  def normalize_auth_configuration
    self.auth_type = auth_type.presence || (ai_secret_id.present? ? "header_secret" : "none")
    self.auth_header = auth_header.presence || "Authorization"
    self.oauth_client_registration ||= "client_metadata_document" if oauth?

    if !oauth?
      self.oauth_client_registration =
        oauth_client_registration.presence || "client_metadata_document"
    elsif oauth_client_registration != "manual"
      self.oauth_client_id = nil
      self.oauth_client_secret_ai_secret_id = nil
    end

    self.ai_secret_id = nil if !header_secret?
  end

  def validate_ai_secret_id_exists
    return if ai_secret_id.blank? || AiSecret.exists?(ai_secret_id)

    errors.add(:ai_secret_id, I18n.t("discourse_ai.mcp_servers.secret_not_found"))
  end

  def validate_oauth_client_secret_id_exists
    if oauth_client_secret_ai_secret_id.blank? || AiSecret.exists?(oauth_client_secret_ai_secret_id)
      return
    end

    errors.add(
      :oauth_client_secret_ai_secret_id,
      I18n.t("discourse_ai.mcp_servers.secret_not_found"),
    )
  end

  def validate_oauth_configuration
    return unless oauth?

    if oauth_client_registration == "manual" && oauth_client_id.blank?
      errors.add(:oauth_client_id, I18n.t("discourse_ai.mcp_servers.oauth_client_id_required"))
    end
  end

  def validate_public_https_url
    uri = self.class.parse_public_uri(url)

    if uri.nil?
      errors.add(:url, I18n.t("discourse_ai.mcp_servers.invalid_public_https_url"))
      return
    end

    self.class.validate_hostname_public!(uri.hostname)
  rescue FinalDestination::SSRFError, SocketError, URI::InvalidURIError
    errors.add(:url, I18n.t("discourse_ai.mcp_servers.invalid_public_https_url"))
  end

  def flush_tool_cache
    if instance_variable_defined?(:@tools_for_serialization)
      remove_instance_variable(:@tools_for_serialization)
    end
    DiscourseAi::Mcp::ToolRegistry.invalidate!(self.id)
    AiAgent.agent_cache.flush!
  end

  def clear_oauth_tokens_if_auth_type_changed
    previous_auth_type = previous_changes["auth_type"]&.first
    return if previous_auth_type != "oauth" || oauth?

    clear_oauth_credentials!
  end

  def clear_oauth_credentials_if_configuration_changed
    return unless oauth?
    return if (previous_changes.keys & OAUTH_REAUTH_TRIGGER_FIELDS).blank?

    clear_oauth_credentials!
  end

  def clear_oauth_tokens
    oauth_token_store.clear!
  end
end
