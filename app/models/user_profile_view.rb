class UserProfileView < ActiveRecord::Base
  validates_presence_of :user_profile_id, :ip_address, :viewed_at

  belongs_to :user_profile

  def self.add(user_profile_id, ip, user_id=nil, at=nil, skip_redis=false)
    at ||= Time.zone.now
    redis_key = "user-profile-view:#{user_profile_id}:#{at.to_date}"
    if user_id
      redis_key << ":user-#{user_id}"
    else
      redis_key << ":ip-#{ip}"
    end

    if skip_redis || $redis.setnx(redis_key, '1')
      skip_redis || $redis.expire(redis_key, SiteSetting.user_profile_view_duration_hours.hours)

      self.transaction do
        sql = "INSERT INTO user_profile_views (user_profile_id, ip_address, viewed_at, user_id)
               SELECT :user_profile_id, :ip_address, :viewed_at, :user_id
               WHERE NOT EXISTS (
                  SELECT 1 FROM user_profile_views
                  /*where*/
               )"

        builder = SqlBuilder.new(sql)

        if !user_id
          builder.where("viewed_at = :viewed_at AND ip_address = :ip_address AND user_profile_id = :user_profile_id AND user_id IS NULL")
        else
          builder.where("viewed_at = :viewed_at AND user_id = :user_id AND user_profile_id = :user_profile_id")
        end

        result = builder.exec(user_profile_id: user_profile_id, ip_address: ip, viewed_at: at, user_id: user_id)

        if result.cmd_tuples > 0
          UserProfile.find(user_profile_id).increment!(:views)
        end
      end
    end
  end

  def self.profile_views_by_day(start_date, end_date)
    profile_views = self.where("viewed_at >= ? AND viewed_at < ?", start_date, end_date + 1.day)
    profile_views.group("date(viewed_at)").order("date(viewed_at)").count
  end
end
