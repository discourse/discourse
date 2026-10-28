# frozen_string_literal: true

class McpAccessRuleUpdater
  def self.replace!(actor:, group_id:, scopes:)
    new(actor:, group_id:, scopes:).replace!
  end

  def self.delete!(actor:, group_id:)
    new(actor:, group_id:, scopes: []).delete!
  end

  def initialize(actor:, group_id:, scopes:)
    @actor = actor
    @group_id = group_id.to_i
    @scopes = (Array(scopes).map(&:to_s) + [DiscourseMcp::INITIAL_SCOPE]).uniq.sort
  end

  def replace!
    validate_group!
    validate_scopes!

    McpGroupScope.transaction do
      McpGroupScope.where(group_id: group_id).delete_all
      scopes.each { |scope| McpGroupScope.create!(group_id: group_id, scope: scope) }
      log_change("mcp_access_rule_updated", scopes)
    end
  end

  def delete!
    validate_group!
    raise Discourse::InvalidParameters.new(:group_id) if group_id == Group::AUTO_GROUPS[:admins]

    McpGroupScope.transaction do
      removed_scopes = McpGroupScope.where(group_id: group_id).order(:scope).pluck(:scope)
      McpGroupScope.where(group_id: group_id).delete_all
      log_change("mcp_access_rule_deleted", removed_scopes)
    end
  end

  private

  attr_reader :actor, :group_id, :scopes

  def validate_group!
    raise Discourse::InvalidParameters.new(:group_id) if !Group.exists?(id: group_id)
  end

  def validate_scopes!
    if (scopes - DiscourseMcp.registry.scopes).present?
      raise Discourse::InvalidParameters.new(:scopes)
    end
  end

  def log_change(action, logged_scopes)
    StaffActionLogger.new(actor).log_custom(action, group_id: group_id, scopes: logged_scopes)
  end
end
