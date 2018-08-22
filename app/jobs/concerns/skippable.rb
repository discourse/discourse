module Skippable
  extend ActiveSupport::Concern

  def create_skipped_email_log(email_type:,
                               to_address:,
                               user_id:,
                               post_id:,
                               reason_type:)

    attributes = {
      email_type: email_type,
      to_address: to_address,
      user_id: user_id,
      post_id: post_id,
      reason_type: reason_type
    }

    if reason_type == SkippedEmailLog.reason_types[:exceeded_emails_limit]
      exists = SkippedEmailLog.exists?({
        created_at: (Time.zone.now.beginning_of_day..Time.zone.now.end_of_day)
      }.merge!(attributes.except(:post_id)))

      return if exists
    end

    SkippedEmailLog.create!(attributes)
  end
end
