# frozen_string_literal: true

class EmailLog < ActiveRecord::Base
  CRITICAL_EMAIL_TYPES =
    Set.new %w[
              account_created
              admin_login
              confirm_new_email
              confirm_old_email
              confirm_old_email_add
              forgot_password
              notify_old_email
              notify_old_email_add
              signup
              signup_after_approval
            ]

  # cf. https://www.iana.org/assignments/smtp-enhanced-status-codes/smtp-enhanced-status-codes.xhtml
  SMTP_ERROR_CODE_REGEXP = Regexp.new(/\d\.\d\.\d+|\d{3}/).freeze

  belongs_to :user
  belongs_to :post
  belongs_to :smtp_group, class_name: "Group"

  validates :email_type, :to_address, presence: true

  scope :bounced, -> { where(bounced: true) }

  scope :addressed_to_user, ->(user) { where(<<~SQL, user_id: user.id) }
      EXISTS(
        SELECT 1
        FROM user_emails
        WHERE user_emails.user_id = :user_id AND
        (email_logs.to_address = user_emails.email OR
         email_logs.cc_addresses ILIKE '%' || user_emails.email || '%')
      )
    SQL

  before_save do
    if self.bounce_error_code.present?
      match = SMTP_ERROR_CODE_REGEXP.match(self.bounce_error_code)
      self.bounce_error_code = match.present? ? match[0] : nil
    end
  end

  after_create do
    # Update last_emailed_at if the user_id is present and email was sent
    User.where(id: user_id).update_all("last_emailed_at = CURRENT_TIMESTAMP") if user_id.present?
  end

  def topic
    @topic ||= self.topic_id.present? ? Topic.find_by(id: self.topic_id) : self.post&.topic
  end

  def self.unique_email_per_post(post, user)
    return yield unless post && user

    DistributedMutex.synchronize("email_log_#{post.id}_#{user.id}") do
      if where(post_id: post.id, user_id: user.id).exists?
        nil
      else
        yield
      end
    end
  end

  def self.reached_max_emails?(user, email_type = nil)
    if SiteSetting.max_emails_per_day_per_user == 0 || CRITICAL_EMAIL_TYPES.include?(email_type)
      return false
    end

    count = where("created_at > ?", 1.day.ago).where(user_id: user.id).count

    count >= SiteSetting.max_emails_per_day_per_user
  end

  def self.count_per_day(start_date, end_date)
    where("created_at BETWEEN ? AND ?", start_date, end_date)
      .group("DATE(created_at)")
      .order("DATE(created_at)")
      .count
  end

  def self.for(reply_key)
    self.find_by(reply_key: reply_key)
  end

  def self.last_sent_email_address
    self.where(email_type: "signup").order(created_at: :desc).limit(1).pluck(:to_address).first
  end

  def bounce_key
    super&.delete("-")
  end

  def cc_users
    return [] if !self.cc_user_ids
    @cc_users ||= User.where(id: self.cc_user_ids)
  end

  def cc_addresses_split
    @cc_addresses_split ||= self.cc_addresses&.split(";") || []
  end

  def as_mail_message
    return if self.raw.blank?
    @mail_message ||= Mail.new(self.raw)
  end

  def raw_headers
    return if self.raw.blank?
    as_mail_message.header.raw_source
  end

  def raw_body
    return if self.raw.blank?
    as_mail_message.body
  end
end

# == Schema Information
#
# Table name: email_logs
#
#  id                        :integer          not null, primary key
#  to_address                :string           not null
#  email_type                :string           not null
#  user_id                   :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  post_id                   :integer
#  bounce_key                :uuid
#  bounced                   :boolean          default(FALSE), not null
#  message_id                :string
#  smtp_group_id             :integer
#  cc_addresses              :text
#  cc_user_ids               :integer          is an Array
#  raw                       :text
#  topic_id                  :integer
#  bounce_error_code         :string
#  smtp_transaction_response :string(500)
#  bcc_addresses             :text
#
# Indexes
#
#  index_email_logs_on_bounce_key  (bounce_key) UNIQUE WHERE (bounce_key IS NOT NULL)
#  index_email_logs_on_bounced     (bounced)
#  index_email_logs_on_created_at  (created_at)
#  index_email_logs_on_message_id  (message_id)
#  index_email_logs_on_post_id     (post_id)
#  index_email_logs_on_topic_id    (topic_id) WHERE (topic_id IS NOT NULL)
#  index_email_logs_on_user_id     (user_id)
#
