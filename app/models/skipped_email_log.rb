# frozen_string_literal: true

class SkippedEmailLog < ActiveRecord::Base
  belongs_to :email_log

  belongs_to :user
  belongs_to :post
  has_one :topic, through: :post

  validates :email_type, :to_address, :reason_type, presence: true

  validates :custom_reason, presence: true, if: -> { is_custom? }
  validates :custom_reason, absence: true, if: -> { !is_custom? }
  validate :ensure_valid_reason_type

  def self.reason_types
    @types ||= Enum.new(
      custom: 1,
      exceeded_emails_limit: 2,
      exceeded_bounces_limit: 3,
      mailing_list_no_echo_mode: 4,
      user_email_no_user: 5,
      user_email_post_not_found: 6,
      user_email_anonymous_user: 7,
      user_email_user_suspended_not_pm: 8,
      user_email_seen_recently: 9,
      user_email_notification_already_read: 10,
      user_email_topic_nil: 11,
      user_email_post_user_deleted: 12,
      user_email_post_deleted: 13,
      user_email_user_suspended: 14,
      user_email_already_read: 15,
      sender_message_blank: 16,
      sender_message_to_blank: 17,
      sender_text_part_body_blank: 18,
      sender_body_blank: 19,
      sender_post_deleted: 20,
      sender_message_to_invalid: 21,
      user_email_access_denied: 22
      # you need to add the reason in server.en.yml below the "skipped_email_log" key
      # when you add a new enum value
    )
  end

  def reason
    if is_custom?
      self.custom_reason
    else
      type = self.reason_type

      I18n.t(
        "skipped_email_log.#{SkippedEmailLog.reason_types[type]}",
        user_id: self.user_id,
        post_id: self.post_id
      )
    end
  end

  private

  def is_custom?
    self.reason_type == self.class.reason_types[:custom]
  end

  def ensure_valid_reason_type
    unless self.class.reason_types[self.reason_type]
      self.errors.add(:reason_type, :invalid)
    end
  end
end

# == Schema Information
#
# Table name: skipped_email_logs
#
#  id            :bigint           not null, primary key
#  email_type    :string           not null
#  to_address    :string           not null
#  user_id       :integer
#  post_id       :integer
#  reason_type   :integer          not null
#  custom_reason :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_skipped_email_logs_on_created_at   (created_at)
#  index_skipped_email_logs_on_post_id      (post_id)
#  index_skipped_email_logs_on_reason_type  (reason_type)
#  index_skipped_email_logs_on_user_id      (user_id)
#
