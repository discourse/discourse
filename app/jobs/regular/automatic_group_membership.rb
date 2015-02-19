module Jobs

  class AutomaticGroupMembership < Jobs::Base

    def execute(args)
      group_id = args[:group_id]

      raise Discourse::InvalidParameters.new(:group_id) if group_id.blank?

      group = Group.find(group_id)

      return unless group.automatic_membership_retroactive

      domains = group.automatic_membership_email_domains.gsub('.', '\.')

      User.where("email ~* '@(#{domains})$'").find_each do |user|
        group.add(user) rescue ActiveRecord::RecordNotUnique
      end
    end

  end

end
