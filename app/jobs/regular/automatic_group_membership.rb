module Jobs

  class AutomaticGroupMembership < Jobs::Base

    def execute(args)
      group_id = args[:group_id]
      raise Discourse::InvalidParameters.new(:group_id) if group_id.blank?

      group = Group.find_by(id: group_id)
      raise Discourse::InvalidParameters.new(:group_id) if group.nil?

      return unless group.automatic_membership_retroactive

      domains = group.automatic_membership_email_domains.gsub('.', '\.')

      User.joins(:user_emails)
        .where("user_emails.email ~* '@(#{domains})$'")
        .where("users.id NOT IN (SELECT user_id FROM group_users WHERE group_users.group_id = ?)", group_id)
        .activated
        .where(staged: false)
        .find_each do |user|
        next unless user.email_confirmed?
        group.add(user)
        GroupActionLogger.new(Discourse.system_user, group).log_add_user_to_group(user)
      end

      Group.reset_counters(group.id, :group_users)
    end

  end

end
