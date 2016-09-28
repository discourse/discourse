module Jobs
  class PurgeInactive < Jobs::Scheduled
    every 1.day

    # Delete unactivated accounts (without verified email) that are over a week old
    def execute(args)
      to_destroy = User.where(active: false)
                       .joins('INNER JOIN user_stats AS us ON us.user_id = users.id')
                       .where("created_at < ?", SiteSetting.purge_unactivated_users_grace_period_days.days.ago)
                       .where('NOT admin AND NOT moderator')
                       .limit(200)

      destroyer = UserDestroyer.new(Discourse.system_user)
      to_destroy.each do |u|
        begin
          destroyer.destroy(u, context: I18n.t(:purge_reason))
        rescue Discourse::InvalidAccess, UserDestroyer::PostsExistError
          # if for some reason the user can't be deleted, continue on to the next one
        end
      end
    end
  end
end