# frozen_string_literal: true

module Jobs
  class AnonymizeUser < ::Jobs::Base
    sidekiq_options queue: "low"
    # this is an extremely expensive job
    # we are limiting it so only 1 per cluster runs
    cluster_concurrency 1

    def execute(args)
      @user_id = args[:user_id]
      @prev_emails = args[:prev_emails]
      @prev_username = args[:prev_username]
      @anonymize_ip = args[:anonymize_ip]

      make_anonymous
    end

    def make_anonymous
      anonymize_ips(@anonymize_ip) if @anonymize_ip
      anonymize_username if @prev_username && !SiteSetting.log_anonymizer_details?

      Invite.where(email: @prev_emails).destroy_all
      InvitedUser.where(user_id: @user_id).destroy_all
      EmailToken.where(user_id: @user_id).destroy_all
      EmailLog.where(user_id: @user_id).delete_all
      IncomingEmail.where("user_id = ? OR from_address IN (?)", @user_id, @prev_emails).delete_all

      Post
        .with_deleted
        .where(user_id: @user_id)
        .where.not(raw_email: nil)
        .update_all(raw_email: nil)

      anonymize_user_fields
    end

    def ip_where(column = "user_id")
      ["#{column} = :user_id AND ip_address IS NOT NULL", user_id: @user_id]
    end

    def anonymize_ips(new_ip)
      IncomingLink.where(ip_where("current_user_id")).update_all(ip_address: new_ip)
      ScreenedEmail.where(email: @prev_emails).update_all(ip_address: new_ip)
      SearchLog.where(ip_where).update_all(ip_address: new_ip)
      TopicLinkClick.where(ip_where).update_all(ip_address: new_ip)
      TopicViewItem.where(ip_where).update_all(ip_address: new_ip)
      UserHistory.where(ip_where("acting_user_id")).update_all(ip_address: new_ip)
      UserProfileView.where(ip_where).update_all(ip_address: new_ip)
      UserIpAddressHistory.where(user_id: @user_id).delete_all

      # UserHistory for delete_user logs the user's IP. Note this is quite ugly but we don't
      # have a better way of querying on details right now.
      UserHistory.where(
        "action = :action AND details LIKE :details",
        action: UserHistory.actions[:delete_user],
        details: "id: #{@user_id}\n%",
      ).update_all(ip_address: new_ip)
    end

    def anonymize_user_fields
      user_field_ids = UserField.pluck(:id)
      user = User.find(@user_id)
      return if user_field_ids.blank? || user.blank?

      user_field_ids.each do |field_id|
        user.custom_fields.delete("#{User::USER_FIELD_PREFIX}#{field_id}")
      end

      user.save!
    end

    def anonymize_username
      pattern = "%#{UserHistory.sanitize_sql_like(@prev_username)}%"
      reason = I18n.t("user.anonymized")

      sql = <<~SQL
        context = CASE WHEN context LIKE :pattern THEN :reason ELSE context END,
        details = CASE WHEN details LIKE :pattern THEN :reason ELSE details END,
        previous_value = CASE WHEN previous_value LIKE :pattern THEN :reason ELSE previous_value END,
        new_value = CASE WHEN new_value LIKE :pattern THEN :reason ELSE new_value END
      SQL

      UserHistory
        .where(target_user_id: @user_id)
        .where(
          "context LIKE :pattern OR details LIKE :pattern OR previous_value LIKE :pattern OR new_value LIKE :pattern",
          pattern:,
        )
        .update_all([sql, { pattern:, reason: }])
    end
  end
end
