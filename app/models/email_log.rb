class EmailLog < ActiveRecord::Base
  belongs_to :user
  validates_presence_of :email_type
  validates_presence_of :to_address

  after_create do
    # Update last_emailed_at if the user_id is present
    User.update_all("last_emailed_at = CURRENT_TIMESTAMP", id: user_id) if user_id.present?
  end

  def self.count_per_day(sinceDaysAgo = 30)
    where('created_at > ?', sinceDaysAgo.days.ago).group('date(created_at)').order('date(created_at)').count
  end
end
