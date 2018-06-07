module Jobs
  class AnonymizeUser < Jobs::Base

    sidekiq_options queue: 'low'

    def execute(args)
      @user_id = args[:user_id]
      @prev_email = args[:prev_email]
      @anonymize_ip = args[:anonymize_ip]

      make_anonymous
    end

    def make_anonymous
      anonymize_ips(@anonymize_ip) if @anonymize_ip

      Invite.with_deleted.where(user_id: @user_id).destroy_all
      EmailToken.where(user_id: @user_id).destroy_all
      EmailLog.where(user_id: @user_id).delete_all
      IncomingEmail.where("user_id = ? OR from_address = ?", @user_id, @prev_email).delete_all

      Post.with_deleted
        .where(user_id: @user_id)
        .where.not(raw_email: nil)
        .update_all(raw_email: nil)
    end

    def ip_where(column = 'user_id')
      ["#{column} = :user_id AND ip_address IS NOT NULL", user_id: @user_id]
    end

    def anonymize_ips(new_ip)
      IncomingLink.where(ip_where('current_user_id')).update_all(ip_address: new_ip)
      ScreenedEmail.where(email: @prev_email).update_all(ip_address: new_ip)
      SearchLog.where(ip_where).update_all(ip_address: new_ip)
      TopicLinkClick.where(ip_where).update_all(ip_address: new_ip)
      TopicViewItem.where(ip_where).update_all(ip_address: new_ip)
      UserHistory.where(ip_where('acting_user_id')).update_all(ip_address: new_ip)
      UserProfileView.where(ip_where).update_all(ip_address: new_ip)

      # UserHistory for delete_user logs the user's IP. Note this is quite ugly but we don't
      # have a better way of querying on details right now.
      UserHistory.where(
        "action = :action AND details LIKE 'id: #{@user_id}\n%'",
        action: UserHistory.actions[:delete_user]
      ).update_all(ip_address: new_ip)
    end

  end
end
