require 'ipaddr'

class View < ActiveRecord::Base
  belongs_to :parent, polymorphic: true
  belongs_to :user
  validates_presence_of :parent_type, :parent_id, :ip_address, :viewed_at

  # TODO: This could happen asyncronously
  def self.create_for(parent, ip, user=nil)

    # Only store a view once per day per thing per user per ip
    redis_key = "view:#{parent.class.name}:#{parent.id}:#{Date.today.to_s}"
    if user.present?
      redis_key << ":user-#{user.id}"
    else
      redis_key << ":ip-#{ip}"
    end

    if $redis.setnx(redis_key, "1")
      $redis.expire(redis_key, 1.day.to_i)

      View.transaction do
        View.create(parent: parent, ip_address: ip, viewed_at: Date.today, user: user)

        # Update the views count in the parent, if it exists.
        if parent.respond_to?(:views)
          parent.class.where(id: parent.id).update_all 'views = views + 1'
        end
      end
    end
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
#  index_views_on_parent_id_and_parent_type  (parent_id,parent_type)
#

