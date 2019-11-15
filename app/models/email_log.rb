# frozen_string_literal: true

class EmailLog < ActiveRecord::Base
  CRITICAL_EMAIL_TYPES ||= Set.new %w{
    account_created
    admin_login
    confirm_new_email
    confirm_old_email
    forgot_password
    notify_old_email
    signup
    signup_after_approval
  }

  belongs_to :user
  belongs_to :post
  has_one :topic, through: :post

  validates :email_type, :to_address, presence: true

  scope :bounced, -> { where(bounced: true) }

  after_create do
    # Update last_emailed_at if the user_id is present and email was sent
    User.where(id: user_id).update_all("last_emailed_at = CURRENT_TIMESTAMP") if user_id.present?
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
    return false if SiteSetting.max_emails_per_day_per_user == 0 || CRITICAL_EMAIL_TYPES.include?(email_type)

    count = where('created_at > ?', 1.day.ago)
      .where(user_id: user.id)
      .count

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
    self.where(email_type: "signup")
      .order(created_at: :desc)
      .limit(1)
      .pluck(:to_address)
      .first
  end

  def bounce_key
    super&.delete('-')
  end

end

# == Schema Information
#
# Table name: email_logs
#
#  id         :integer          not null, primary key
#  to_address :string           not null
#  email_type :string           not null
#  user_id    :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  post_id    :integer
#  bounce_key :uuid
#  bounced    :boolean          default(FALSE), not null
#  message_id :string
#
# Indexes
#
#  index_email_logs_on_bounce_key  (bounce_key) UNIQUE WHERE (bounce_key IS NOT NULL)
#  index_email_logs_on_bounced     (bounced)
#  index_email_logs_on_created_at  (created_at)
#  index_email_logs_on_message_id  (message_id)
#  index_email_logs_on_post_id     (post_id)
#  index_email_logs_on_user_id     (user_id)
#
