class UserVisit < ActiveRecord::Base
  attr_accessible :visited_at, :user_id

  # A list of visits in the last month by day
  def self.by_day(since=30.days.ago)
    where("visited_at > ?", since).group(:visited_at).order(:visited_at).count
  end
end
