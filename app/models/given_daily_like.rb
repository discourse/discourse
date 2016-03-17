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
