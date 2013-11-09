require 'ipaddr'

class View < ActiveRecord::Base
  belongs_to :parent, polymorphic: true
  belongs_to :user
  validates_presence_of :parent_type, :parent_id, :ip_address, :viewed_at

  def self.create_for_parent(parent_class, parent_id, ip, user_id)
    # Only store a view once per day per thing per user per ip
    redis_key = "view:#{parent_class.name}:#{parent_id}:#{Date.today.to_s}"
    if user_id
      redis_key << ":user-#{user_id}"
    else
      redis_key << ":ip-#{ip}"
    end

    if $redis.setnx(redis_key, "1")
      $redis.expire(redis_key, 1.day.to_i)

      View.transaction do
        View.create!(parent_id: parent_id, parent_type: parent_class.to_s, ip_address: ip, viewed_at: Date.today, user_id: user_id)

        # Update the views count in the parent, if it exists.
        if parent_class.columns_hash["views"]
          parent_class.where(id: parent_id).update_all 'views = views + 1'
        end
      end
    end
  end

  def self.create_for(parent, ip, user=nil)
    user_id = user.id if user
    create_for_parent(parent.class, parent.id, ip, user_id)
  end
end

# == Schema Information
#
# Table name: views
#
#  parent_id   :integer          not null
#  parent_type :string(50)       not null
#  viewed_at   :date             not null
#  user_id     :integer
#  ip_address  :string           not null
#
# Indexes
#
#  index_views_on_parent_id_and_parent_type              (parent_id,parent_type)
#  index_views_on_user_id_and_parent_type_and_parent_id  (user_id,parent_type,parent_id)
#

