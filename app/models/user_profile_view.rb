# frozen_string_literal: true

class UserProfileView < ActiveRecord::Base
  validates_presence_of :user_profile_id, :viewed_at

  belongs_to :user_profile

  def self.add(user_profile_id, ip, user_id = nil, at = nil, skip_redis = false)
    at ||= Time.zone.now
    redis_key = +"user-profile-view:#{user_profile_id}:#{at.to_date}"
    if user_id
      return if user_id < 1
      redis_key << ":user-#{user_id}"
      ip = nil
    else
      redis_key << ":ip-#{ip}"
    end

    if skip_redis || Discourse.redis.setnx(redis_key, '1')
      skip_redis || Discourse.redis.expire(redis_key, SiteSetting.user_profile_view_duration_hours.hours)

      self.transaction do
        sql = "INSERT INTO user_profile_views (user_profile_id, ip_address, viewed_at, user_id)
               SELECT :user_profile_id, :ip_address, :viewed_at, :user_id
               WHERE NOT EXISTS (
                  SELECT 1 FROM user_profile_views
                  /*where*/
               )"

        builder = DB.build(sql)

        if !user_id
          builder.where("viewed_at = :viewed_at AND ip_address = :ip_address AND user_profile_id = :user_profile_id AND user_id IS NULL")
        else
          builder.where("viewed_at = :viewed_at AND user_id = :user_id AND user_profile_id = :user_profile_id")
        end

        result = builder.exec(user_profile_id: user_profile_id, ip_address: ip, viewed_at: at, user_id: user_id)

        if result > 0
          UserProfile.find(user_profile_id).increment!(:views)
        end
      end
    end
  end

  def self.profile_views_by_day(start_date, end_date, group_id = nil)
    profile_views = self.where("viewed_at >= ? AND viewed_at < ?", start_date, end_date + 1.day)
    if group_id
      profile_views = profile_views.joins("INNER JOIN users ON users.id = user_profile_views.user_id")
      profile_views = profile_views.joins("INNER JOIN group_users ON group_users.user_id = users.id")
      profile_views = profile_views.where("group_users.group_id = ?", group_id)
    end
    profile_views.group("date(viewed_at)").order("date(viewed_at)").count
  end
end

# == Schema Information
#
# Table name: user_profile_views
#
#  id              :integer          not null, primary key
#  user_profile_id :integer          not null
#  viewed_at       :datetime         not null
#  ip_address      :inet
#  user_id         :integer
#
# Indexes
#
#  index_user_profile_views_on_user_id          (user_id)
#  index_user_profile_views_on_user_profile_id  (user_profile_id)
#  unique_profile_view_user_or_ip               (viewed_at,user_id,ip_address,user_profile_id) UNIQUE
#
