class GivenDailyLike < ActiveRecord::Base
  belongs_to :user

  def self.find_for(user_id, date)
    where(user_id: user_id, given_date: date)
  end

  def self.increment_for(user_id)
    return unless user_id
    given_date = Date.today

    # upsert would be nice here
    rows = find_for(user_id, given_date).update_all('likes_given = likes_given + 1')

    if rows == 0
      create(user_id: user_id, given_date: given_date, likes_given: 1)
    else
      find_for(user_id, given_date)
        .where('limit_reached = false AND likes_given >= :limit', limit: SiteSetting.max_likes_per_day)
        .update_all(limit_reached: true)
    end
  end

  def self.decrement_for(user_id)
    return unless user_id

    given_date = Date.today

    find_for(user_id, given_date).update_all('likes_given = likes_given - 1')
    find_for(user_id, given_date)
      .where('limit_reached = true AND likes_given < :limit', limit: SiteSetting.max_likes_per_day)
      .update_all(limit_reached: false)
  end
end

# == Schema Information
#
# Table name: given_daily_likes
#
#  user_id       :integer          not null
#  likes_given   :integer          not null
#  given_date    :date             not null
#  limit_reached :boolean          default(FALSE), not null
#
# Indexes
#
#  index_given_daily_likes_on_limit_reached_and_user_id  (limit_reached,user_id)
#  index_given_daily_likes_on_user_id_and_given_date     (user_id,given_date) UNIQUE
#
