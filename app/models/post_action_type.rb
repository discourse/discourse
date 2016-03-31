require_dependency 'enum'
require_dependency 'distributed_cache'

class PostActionType < ActiveRecord::Base
  after_save :expire_cache
  after_destroy :expire_cache

  def expire_cache
    ApplicationSerializer.expire_cache_fragment!("post_action_types")
    ApplicationSerializer.expire_cache_fragment!("post_action_flag_types")
  end

  class << self

    def ordered
      order('position asc')
    end

    def types
      @types ||= Enum.new(bookmark: 1,
                          like: 2,
                          off_topic: 3,
                          inappropriate: 4,
                          vote: 5,
                          notify_user: 6,
                          notify_moderators: 7,
                          spam: 8)
    end

    def auto_action_flag_types
      @auto_action_flag_types ||= flag_types.except(:notify_user, :notify_moderators)
    end

    def public_types
      @public_types ||= types.except(*flag_types.keys << :notify_user)
    end

    def public_type_ids
      @public_type_ids ||= public_types.values
    end

    def flag_types
      @flag_types ||= types.only(:off_topic, :spam, :inappropriate, :notify_moderators)
    end

    # flags resulting in mod notifications
    def notify_flag_type_ids
      @notify_flag_type_ids ||= types.only(:off_topic, :spam, :inappropriate, :notify_moderators).values
    end

    def topic_flag_types
      @topic_flag_types ||= types.only(:spam, :inappropriate, :notify_moderators)
    end

    def is_flag?(sym)
      flag_types.valid?(sym)
    end
  end
end

# == Schema Information
#
# Table name: post_action_types
#
#  name_key   :string(50)       not null
#  is_flag    :boolean          default(FALSE), not null
#  icon       :string(20)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  id         :integer          not null, primary key
#  position   :integer          default(0), not null
#
