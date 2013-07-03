class EmailLog < ActiveRecord::Base
  belongs_to :user
  validates_presence_of :email_type
  validates_presence_of :to_address

  belongs_to :post
  belongs_to :topic

  after_create do
    # Update last_emailed_at if the user_id is present
    User.where(id: user_id).update_all("last_emailed_at = CURRENT_TIMESTAMP") if user_id.present?
  end

  def self.count_per_day(sinceDaysAgo = 30)
    where('created_at > ?', sinceDaysAgo.days.ago).group('date(created_at)').order('date(created_at)').count
  end

  def self.for(reply_key)
    EmailLog.where(reply_key: reply_key).first
  end

end

# == Schema Information
#
# Table name: email_logs
#
#  id         :integer          not null, primary key
#  to_address :string(255)      not null
#  email_type :string(255)      not null
#  user_id    :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  reply_key  :string(32)
#  post_id    :integer
#  topic_id   :integer
#
# Indexes
#
#  index_email_logs_on_created_at              (created_at)
#  index_email_logs_on_reply_key               (reply_key)
#  index_email_logs_on_user_id_and_created_at  (user_id,created_at)
#

