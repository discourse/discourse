require_dependency 'admin_user_index_query'

module Jobs

  class PendingUsersReminder < Jobs::Scheduled

    recurrence { daily.hour_of_day(9) }

    def execute(args)
      if SiteSetting.must_approve_users
        count = AdminUserIndexQuery.new({query: 'pending'}).find_users_query.count
        if count > 0
          GroupMessage.create(Group[:moderators].name, :pending_users_reminder, {limit_once_per: false, message_params: {count: count}})
        end
      end
    end

  end

end
