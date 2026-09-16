# frozen_string_literal: true

class Admin::McpController < Admin::AdminController
  def overview
    exposed =
      McpPrimitive.exposed.filter_map do |policy|
        primitive = DiscourseMcp.registry.find(policy.kind, policy.identifier)
        next if !primitive&.available?
        primitive
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
             warnings: [],
           }
  end

  def access
    render json: primitives_payload.merge(access_rules: access_rules_payload)
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
            primitive_payload(primitive, primitive_record)
          end
      end
    {
      initial_scope: DiscourseMcp::INITIAL_SCOPE,
      available_scopes: DiscourseMcp.registry.scopes,
      primitives: primitives,
    }
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
