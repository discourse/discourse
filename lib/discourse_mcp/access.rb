# frozen_string_literal: true

module DiscourseMcp
  class Access
    def self.eligible_scopes(user)
      eligible_scopes_by_user([user])[user&.id] || []
    end

    def self.eligible_scopes_by_user(users)
      users = Array(users).compact.uniq(&:id)
      scopes_by_user_id = users.to_h { |user| [user.id, []] }
      eligible_users = users.select { |user| user_available?(user) }
      McpGroupScope.ensure_admins! if eligible_users.any?(&:admin?)
      return scopes_by_user_id if eligible_users.blank?

      mcp_group_scopes =
        McpGroupScope
          .joins("INNER JOIN group_users ON group_users.group_id = mcp_group_scopes.group_id")
          .where(group_users: { user_id: eligible_users.map(&:id) })
          .where(scope: DiscourseMcp.registry.scopes)
          .distinct
          .pluck("group_users.user_id", "mcp_group_scopes.scope")

      logged_in_users_pseudogroup_scopes =
        McpGroupScope
          .where(group_id: Group::AUTO_GROUPS[:logged_in_users])
          .where(scope: DiscourseMcp.registry.scopes)
          .pluck("mcp_group_scopes.scope")

      mcp_group_scopes.each { |user_id, scope| scopes_by_user_id[user_id] << scope }

      logged_in_users_pseudogroup_scopes.each do |scope|
        eligible_users.each { |user| scopes_by_user_id[user.id] << scope }
      end

      scopes_by_user_id.each_value do |scopes|
        if scopes.present? && !scopes.include?(DiscourseMcp::INITIAL_SCOPE)
          scopes << DiscourseMcp::INITIAL_SCOPE
        end
        scopes.uniq!
        scopes.sort!
      end

      scopes_by_user_id
    end

    def self.user_available?(user)
      user.present? && user.active? && !user.suspended? && !user.staged?
    end

    def self.eligible_for_exposed_primitive?(user)
      return false if !SiteSetting.mcp_server_enabled

      eligible_scopes = eligible_scopes(user).to_set
      return false if eligible_scopes.empty?

      McpPrimitive
        .exposed
        .pluck(:kind, :identifier)
        .any? do |kind, identifier|
          primitive = DiscourseMcp.registry.find(kind, identifier)
          primitive&.available? &&
            primitive.required_scopes.all? { |scope| eligible_scopes.include?(scope) }
        end
    end

    def self.allowed?(user)
      eligible_scopes(user).present?
    end
  end
end
