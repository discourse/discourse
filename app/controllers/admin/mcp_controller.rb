# frozen_string_literal: true

class Admin::McpController < Admin::AdminController
  def overview
    content_policy = DiscourseMcp::ContentPolicy.load
    exposed =
      McpPrimitive.exposed.filter_map do |policy|
        primitive = DiscourseMcp.registry.find(policy.kind, policy.identifier)
        next if !primitive&.available?
        primitive
      end
    blocked = exposed.count { |primitive| !content_policy.usable_by_agents?(primitive) }
    exposed = exposed.select { |primitive| content_policy.usable_by_agents?(primitive) }
    warnings = []
    if blocked.positive?
      warnings << I18n.t("mcp.admin.content_restrictions_blocking", count: blocked)
    end
    enabled = SiteSetting.mcp_server_enabled
    metrics = {
      approved_oauth_clients: McpOauthClient.where(trust_state: "approved").count,
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
             catalog: {
               tools: exposed.count { |primitive| primitive.kind == :tool },
               resources:
                 exposed.count { |primitive|
                   %i[resource resource_template].include?(primitive.kind)
                 },
               prompts: exposed.count { |primitive| primitive.kind == :prompt },
               schema_bytes:
                 exposed.sum { |primitive| JSON.generate(primitive.input_schema).bytesize },
             },
             metrics: metrics,
             approved_oauth_clients: metrics[:approved_oauth_clients],
             active_authorizations: metrics[:authorizations],
             active_tokens: metrics[:tokens],
             recent_errors: metrics[:errors],
             setup_checklist: [
               {
                 label: I18n.t("mcp.admin.site_enabled"),
                 complete: SiteSetting.mcp_server_enabled,
               },
               { label: I18n.t("mcp.admin.primitives_enabled"), complete: exposed.present? },
               {
                 label: I18n.t("mcp.admin.client_registered"),
                 complete: metrics[:approved_oauth_clients].positive?,
               },
             ],
             content_restrictions: {
               active: content_policy.active?,
               blocked: blocked,
             },
             warnings: warnings,
           }
  end

  def access
    render json:
             primitives_payload.merge(
               access_rules: access_rules_payload,
               private_message_scopes_overridden:
                 content_policy.denies_all?(DiscourseMcp::ContentPolicy::PRIVATE_MESSAGES),
             )
  end

  def content_restrictions
    render json: DiscourseMcp::ContentRestrictionsReport.new.as_json
  end

  def update_content_restriction
    config = params[:config]
    config = config.respond_to?(:to_unsafe_h) ? config.to_unsafe_h : config
    raise Discourse::InvalidParameters.new(:config) if !config.is_a?(Hash)

    McpContentRuleUpdater.save!(actor: current_user, rule_kind: params[:rule_kind], config:)
    content_restrictions
  end

  def destroy_content_restriction
    McpContentRuleUpdater.delete!(actor: current_user, rule_kind: params[:rule_kind])
    head :no_content
  end

  def primitives
    render json: primitives_payload
  end

  def update_access
    McpAccessRuleUpdater.replace!(
      actor: current_user,
      group_id: params.require(:group_id),
      scopes: params.require(:scopes),
    )
    access
  end

  def destroy_access
    McpAccessRuleUpdater.delete!(actor: current_user, group_id: params.require(:group_id))
    head :no_content
  end

  def update_primitives
    McpPrimitiveUpdater.update!(actor: current_user, primitive_ids: params[:primitive_ids])
    render json: primitives_payload
  end

  def emergency_block
    McpPrimitiveUpdater.set_emergency_block!(
      actor: current_user,
      primitive_id: params.require(:primitive_id),
      blocked: params.fetch(:blocked, true),
    )
    render json: { success: true }
  end

  private

  def primitives_payload
    primitive_records = McpPrimitive.all.index_by { |record| [record.kind, record.identifier] }
    primitives =
      DiscourseMcp::Primitive::KINDS.flat_map do |kind|
        DiscourseMcp
          .registry
          .all(kind)
          .map do |primitive|
            primitive_record = primitive_records[[kind.to_s, primitive.identifier]]
            primitive_payload(primitive, primitive_record).merge(
              restricted: !content_policy.usable_by_agents?(primitive),
            )
          end
      end
    {
      initial_scope: DiscourseMcp::INITIAL_SCOPE,
      available_scopes: DiscourseMcp.registry.scopes,
      primitives: primitives,
    }
  end

  def content_policy
    @content_policy ||= DiscourseMcp::ContentPolicy.load
  end

  def access_rules_payload
    McpGroupScope.ensure_admins!
    rules =
      McpGroupScope
        .includes(:group)
        .order(:group_id, :scope)
        .group_by(&:group_id)
        .filter_map do |group_id, records|
          group = records.first.group
          next if group.blank?

          {
            group_id: group_id,
            group_name: group.name,
            scopes: (records.map(&:scope) | [DiscourseMcp::INITIAL_SCOPE]).sort,
            pre_registered: group_id == Group::AUTO_GROUPS[:admins],
            deletable: group_id != Group::AUTO_GROUPS[:admins],
          }
        end
    rules
  end

  def primitive_payload(primitive, primitive_record)
    {
      id: "#{primitive.kind}:#{primitive.identifier}",
      field_name:
        "primitive_#{primitive.kind}_#{Digest::SHA256.hexdigest(primitive.identifier).first(16)}",
      identifier: primitive.identifier,
      kind: primitive.kind,
      title: primitive.title,
      description: primitive.description,
      provider: primitive.provider,
      risk: primitive.risk,
      required_scopes: primitive.required_scopes,
      enabled: primitive_record&.enabled? || false,
      emergency_blocked: primitive_record&.emergency_blocked? || false,
      available: primitive.available?,
    }
  end
end
