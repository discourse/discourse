# frozen_string_literal: true

class Admin::McpController < Admin::AdminController
  def overview
    profile = McpServerProfile.ensure_default!
    exposed =
      profile.capability_policies.exposed.filter_map do |policy|
        capability = DiscourseMcp.registry.find(policy.kind, policy.identifier)
        next if !capability&.available?
        next if (capability.required_scopes - profile.allowed_scopes).present?

        capability
      end
    enabled = SiteSetting.mcp_server_enabled && profile.enabled?
    metrics = {
      active_clients: McpOauthClient.where(trust_state: "approved").count,
      authorizations: McpOauthAuthorization.active.count,
      tokens: McpOauthAccessToken.usable.count,
      errors:
        McpAuditLog.where("occurred_at > ?", 24.hours.ago).where.not(outcome: "success").count,
    }
    render json: {
             enabled: enabled,
             endpoint: DiscourseMcp.resource_url,
             protocol_version: DiscourseMcp::PROTOCOL_VERSION,
             server_version: Discourse::VERSION::STRING,
             status: enabled ? "available" : "disabled",
             profile: profile_json(profile),
             configuration: profile_json(profile),
             catalog: {
               tools: exposed.count { |capability| capability.kind == :tool },
               resources:
                 exposed.count { |capability|
                   %i[resource resource_template].include?(capability.kind)
                 },
               prompts: exposed.count { |capability| capability.kind == :prompt },
               schema_bytes:
                 exposed.sum { |capability| JSON.generate(capability.input_schema).bytesize },
             },
             metrics: metrics,
             active_clients: metrics[:active_clients],
             active_authorizations: metrics[:authorizations],
             active_tokens: metrics[:tokens],
             recent_errors: metrics[:errors],
             setup_checklist: [
               {
                 label: I18n.t("mcp.admin.site_enabled"),
                 complete: SiteSetting.mcp_server_enabled,
               },
               { label: I18n.t("mcp.admin.profile_enabled"), complete: profile.enabled? },
               {
                 label: I18n.t("mcp.admin.groups_configured"),
                 complete: profile.allowed_group_ids.present?,
               },
               { label: I18n.t("mcp.admin.capabilities_enabled"), complete: exposed.present? },
               {
                 label: I18n.t("mcp.admin.client_registered"),
                 complete: metrics[:active_clients].positive?,
               },
             ],
             warnings: [],
           }
  end

  def capabilities
    profile = McpServerProfile.ensure_default!
    policies = profile.capability_policies.index_by { |policy| [policy.kind, policy.identifier] }
    values =
      %i[tool resource resource_template prompt].flat_map do |kind|
        DiscourseMcp
          .registry
          .all(kind)
          .map do |capability|
            policy = policies[[kind.to_s, capability.identifier]]
            capability_json(capability, policy)
          end
      end
    render json: {
             profile: profile_json(profile),
             available_scopes: DiscourseMcp.registry.scopes,
             capabilities: values,
           }
  end

  def update_configuration
    profile = McpServerProfile.ensure_default!
    permitted =
      params.require(:configuration).permit(
        :enabled,
        :instructions,
        :cache_ttl_ms,
        allowed_group_ids: [],
        allowed_scopes: [],
      )
    previous = profile.slice(*permitted.keys)
    profile.update!(permitted)
    profile.bump_catalog_revision! if previous != profile.slice(*permitted.keys)
    StaffActionLogger.new(current_user).log_custom(
      "mcp_configuration_updated",
      profile_id: profile.id,
    )
    render json: { profile: profile_json(profile) }
  end

  def update_capabilities
    profile = McpServerProfile.ensure_default!
    requested = Array(params[:capability_ids]).map(&:to_s).to_set
    previous_privileged = privileged_enabled_ids(profile)
    McpServerProfileCapability.transaction do
      DiscourseMcp.registry.all.each do |capability|
        policy =
          profile.capability_policies.find_or_initialize_by(
            kind: capability.kind,
            identifier: capability.identifier,
          )
        policy.enabled = requested.include?("#{capability.kind}:#{capability.identifier}")
        policy.save!
      end
      current_privileged = privileged_enabled_ids(profile)
      profile.bump_catalog_revision!(
        consent_relevant: (current_privileged - previous_privileged).present?,
      )
      if (current_privileged - previous_privileged).present?
        profile
          .oauth_authorizations
          .active
          .where("consent_revision < ?", profile.consent_revision)
          .update_all(status: "consent_required")
      end
    end
    StaffActionLogger.new(current_user).log_custom(
      "mcp_capabilities_updated",
      profile_id: profile.id,
      capability_count: requested.length,
    )
    capabilities
  end

  def emergency_block
    profile = McpServerProfile.ensure_default!
    capability_id = params.require(:capability_id).to_s
    kind, identifier = capability_id.split(":", 2)
    raise Discourse::NotFound if DiscourseMcp.registry.find(kind, identifier).blank?

    policy = profile.capability_policies.find_or_initialize_by(kind: kind, identifier: identifier)
    policy.update!(emergency_blocked: params.fetch(:blocked, true))
    profile.bump_catalog_revision!(consent_relevant: true)
    StaffActionLogger.new(current_user).log_custom(
      "mcp_capability_emergency_block_updated",
      profile_id: profile.id,
      capability: capability_id,
      blocked: policy.emergency_blocked?,
    )
    render json: { success: true }
  end

  private

  def profile_json(profile)
    {
      id: profile.id,
      name: profile.name,
      enabled: profile.enabled,
      instructions: profile.instructions,
      allowed_group_ids: profile.allowed_group_ids,
      allowed_scopes: profile.allowed_scopes,
      catalog_revision: profile.catalog_revision,
      consent_revision: profile.consent_revision,
      cache_ttl_ms: profile.cache_ttl_ms,
      endpoint: DiscourseMcp.resource_url,
    }
  end

  def capability_json(capability, policy)
    {
      id: "#{capability.kind}:#{capability.identifier}",
      field_name:
        "capability_#{capability.kind}_#{Digest::SHA256.hexdigest(capability.identifier).first(16)}",
      identifier: capability.identifier,
      kind: capability.kind,
      title: capability.title,
      description: capability.description,
      provider: capability.provider,
      risk: capability.risk,
      scopes: capability.required_scopes,
      required_scopes: capability.required_scopes,
      enabled: policy&.enabled? || false,
      emergency_blocked: policy&.emergency_blocked? || false,
      available: capability.available?,
      schema_bytes: JSON.generate(capability.input_schema).bytesize,
    }
  end

  def privileged_enabled_ids(profile)
    profile
      .capability_policies
      .exposed
      .filter_map do |policy|
        capability = DiscourseMcp.registry.find(policy.kind, policy.identifier)
        policy.identifier if capability&.consent_relevant?
      end
      .to_set
  end
end
