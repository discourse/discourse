require 'ipaddr'

# awkward TopicView is taken
class TopicViewItem < ActiveRecord::Base
  self.table_name = 'topic_views'
  belongs_to :user
  validates_presence_of :topic_id, :ip_address, :viewed_at

  def self.add(topic_id, ip, user_id=nil, at=nil, skip_redis=false)
    # Only store a view once per day per thing per user per ip
    redis_key = "view:#{topic_id}:#{Date.today}"
    if user_id
      redis_key << ":user-#{user_id}"
    else
      redis_key << ":ip-#{ip}"
    end

    if skip_redis || $redis.setnx(redis_key, "1")
      skip_redis || $redis.expire(redis_key, 1.day.to_i)

      TopicViewItem.transaction do
        at ||= Date.today

        # this is called real frequently, working hard to avoid exceptions
        sql = "INSERT INTO topic_views (topic_id, ip_address, viewed_at, user_id)
               SELECT :topic_id, :ip_address, :viewed_at, :user_id
               WHERE NOT EXISTS (
                 SELECT 1 FROM topic_views
                 /*where*/
               )"


        builder = SqlBuilder.new(sql)

        if !user_id
          builder.where("ip_address = :ip_address AND topic_id = :topic_id")
        else
          builder.where("user_id = :user_id AND topic_id = :topic_id")
        end

        result = builder.exec(topic_id: topic_id, ip_address: ip, viewed_at: at, user_id: user_id)

        if result.cmd_tuples > 0
          Topic.where(id: topic_id).update_all 'views = views + 1'
          UserStat.where(user_id: user_id).update_all 'topics_entered = topics_entered + 1' if user_id
        end

        # Update the views count in the parent, if it exists.
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
#  ip_address :inet             not null
#
# Indexes
#
#  index_topic_views_on_topic_id_and_viewed_at  (topic_id,viewed_at)
#  index_topic_views_on_viewed_at_and_topic_id  (viewed_at,topic_id)
#  ip_address_topic_id_topic_views              (ip_address,topic_id) UNIQUE
#  user_id_topic_id_topic_views                 (user_id,topic_id) UNIQUE
#
