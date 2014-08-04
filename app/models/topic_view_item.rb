require 'ipaddr'

# awkward TopicView is taken
class TopicViewItem < ActiveRecord::Base
  self.table_name = 'topic_views'
  belongs_to :user
  validates_presence_of :topic_id, :ip_address, :viewed_at

  def self.add(topic_id, ip, user_id, at=nil)
    # Only store a view once per day per thing per user per ip
    redis_key = "view:#{topic_id}:#{Date.today.to_s}"
    if user_id
      redis_key << ":user-#{user_id}"
    else
      redis_key << ":ip-#{ip}"
    end

    if $redis.setnx(redis_key, "1")
      $redis.expire(redis_key, 1.day.to_i)

      TopicViewItem.transaction do
        at ||= Date.today
        TopicViewItem.create!(topic_id: topic_id, ip_address: ip, viewed_at: at, user_id: user_id)

        # Update the views count in the parent, if it exists.
        Topic.where(id: topic_id).update_all 'views = views + 1'
      end
    end
  rescue ActiveRecord::RecordNotUnique
    # don't care, skip
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
