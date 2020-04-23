# frozen_string_literal: true

module Jobs

  class AutomaticGroupMembership < ::Jobs::Base

    def execute(args)
      group_id = args[:group_id]
      raise Discourse::InvalidParameters.new(:group_id) if group_id.blank?

      group = Group.find_by(id: group_id)
      raise Discourse::InvalidParameters.new(:group_id) if group.nil?

      domains = group.automatic_membership_email_domains
      return if domains.blank?

      Group.automatic_membership_users(domains).find_each do |user|
        next unless user.email_confirmed?
        group.add(user, automatic: true)
        GroupActionLogger.new(Discourse.system_user, group).log_add_user_to_group(user)
      end

      Group.reset_counters(group.id, :group_users)
    end

  end

end
