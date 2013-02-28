class UserVisit < ActiveRecord::Base
  attr_accessible :visited_at, :user_id

  # A list of visits in the last month by day
  def self.by_day
    where("visited_at > ?", 1.month.ago).group(:visited_at).order(:visited_at).count
  end
end
