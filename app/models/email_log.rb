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

  before_save { self.bounce_error_code = self.class.normalize_bounce_error_code(bounce_error_code) }

  # generic enhanced statuses, stored when a provider reports a bounce without
  # one, so that the column always says something about the failure
  BOUNCE_ERROR_CODE_TRANSIENT = "4.0.0"
  BOUNCE_ERROR_CODE_PERMANENT = "5.0.0"

  # every channel reports the status differently, from a bare code to the whole
  # free-form diagnostic, so they all get read the same way
  def self.normalize_bounce_error_code(bounce_error_code)
    Email.extract_smtp_status(bounce_error_code)
  end

  # Atomically claims a bounce report for this log so that duplicate or
  # concurrent reports of the same bounce are recorded (and scored) only once.
  # A permanent failure may supersede an earlier transient report of the same
  # message, since providers often retry after a transient failure and then
  # report a final permanent one.
  def claim_bounce(permanent:, bounce_error_code: nil)
    generic = permanent ? BOUNCE_ERROR_CODE_PERMANENT : BOUNCE_ERROR_CODE_TRANSIENT
    attributes = {
      bounced: true,
      bounce_error_code: self.class.normalize_bounce_error_code(bounce_error_code) || generic,
      bounce_permanent: permanent,
    }

    if !bounced? && self.class.where(id: id, bounced: false).update_all(attributes) == 1
      assign_attributes(attributes)
      return true
    end

    return false if !permanent

    # `bounce_permanent` is NULL for bounces recorded before the severity was
    # tracked. Their error code says what the provider reported, not what they
    # were scored at, so escalating off it would charge a second hard bounce as
    # often as it would catch a real escalation
    escalated =
      self
        .class
        .where(id: id, bounced: true, bounce_permanent: false)
        .update_all(bounce_error_code: attributes[:bounce_error_code], bounce_permanent: true) == 1

    assign_attributes(attributes) if escalated

    escalated
  end

  after_create do
    # Update last_emailed_at if the user_id is present and email was sent
    User.where(id: user_id).update_all("last_emailed_at = CURRENT_TIMESTAMP") if user_id.present?
  end

  def topic
    @topic ||= topic_id.present? ? Topic.find_by(id: topic_id) : post&.topic
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
    find_by(reply_key: reply_key)
  end

  def self.last_sent_email_address
    where(email_type: "signup").order(created_at: :desc).limit(1).pluck(:to_address).first
  end

  def bounce_key
    super&.delete("-")
  end

  def cc_users
    return [] if !cc_user_ids
    @cc_users ||= User.where(id: cc_user_ids)
  end

  def cc_addresses_split
    @cc_addresses_split ||= cc_addresses&.split(";") || []
  end

  def as_mail_message
    return if raw.blank?
    @mail_message ||= Mail.new(raw)
  end

  def raw_headers
    return if raw.blank?
    as_mail_message.header.raw_source
  end

  def raw_body
    return if raw.blank?
    as_mail_message.body
  end
end

# == Schema Information
#
# Table name: email_logs
#
#  id                        :integer          not null, primary key
#  bcc_addresses             :text
#  bounce_error_code         :string
#  bounce_key                :uuid
#  bounce_permanent          :boolean
#  bounced                   :boolean          default(FALSE), not null
#  cc_addresses              :text
#  cc_user_ids               :integer          is an Array
#  email_type                :string           not null
#  raw                       :text
#  smtp_transaction_response :string(500)
#  to_address                :string           not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  message_id                :string
#  post_id                   :integer
#  smtp_group_id             :integer
#  topic_id                  :integer
#  user_id                   :integer
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
