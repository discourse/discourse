# frozen_string_literal: true

require "ipaddr"

# awkward TopicView is taken
class TopicViewItem < ActiveRecord::Base
  self.table_name = "topic_views"
  belongs_to :user
  belongs_to :topic
  validates_presence_of :topic_id, :ip_address, :viewed_at

  def self.add(topic_id, ip, user_id = nil, at = nil, skip_redis = false)
    # Only store a view once per day per thing per (user || ip)
    at ||= Time.zone.today

    redis_key = +"view:#{topic_id}:#{at}"
    if user_id
      redis_key << ":user-#{user_id}"
    else
      redis_key << ":ip-#{ip}"
    end

    if skip_redis || Discourse.redis.setnx(redis_key, "1")
      skip_redis || Discourse.redis.expire(redis_key, SiteSetting.topic_view_duration_hours.hours)

      TopicViewItem.transaction do
        # this is called real frequently, working hard to avoid exceptions
        sql = <<~SQL
          INSERT INTO topic_views (topic_id, ip_address, viewed_at, user_id)
          SELECT :topic_id, :ip_address, :viewed_at, :user_id
          WHERE NOT EXISTS (
            SELECT 1 FROM topic_views
            /*where*/
          )
        SQL

        builder = DB.build(sql)

        if !user_id
          builder.where("ip_address = :ip_address AND topic_id = :topic_id AND user_id IS NULL")
        else
          builder.where("user_id = :user_id AND topic_id = :topic_id")
          ip = nil # do not store IP of logged in users
        end

        result = builder.exec(topic_id: topic_id, ip_address: ip, viewed_at: at, user_id: user_id)

        if result > 0
          if user_id
            UserStat.where(user_id: user_id).update_all "topics_entered = topics_entered + 1"
          end
        end

        Topic.where(id: topic_id).update_all "views = views + 1"

        TopicViewStat.add(
          topic_id: topic_id,
          date: at,
          anonymous_views: user_id ? 0 : 1,
          logged_in_views: user_id ? 1 : 0,
        )
      end
    end
  end
end

# == Schema Information
#
# Table name: topic_views
#
#  topic_id   :integer          not null
#  viewed_at  :date             not null
#  user_id    :integer
#  ip_address :inet
#
# Indexes
#
#  index_topic_views_on_topic_id_and_viewed_at  (topic_id,viewed_at)
#  index_topic_views_on_user_id_and_viewed_at   (user_id,viewed_at)
#  index_topic_views_on_viewed_at_and_topic_id  (viewed_at,topic_id)
#  uniq_ip_or_user_id_topic_views               (user_id,ip_address,topic_id) UNIQUE
#
