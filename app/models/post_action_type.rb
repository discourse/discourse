require_dependency 'enum'

class PostActionType < ActiveRecord::Base
  class << self
    def ordered
      order('position asc')
    end

    def types
      @types ||= Enum.new(:bookmark, :like, :off_topic, :inappropriate, :vote,
                          :notify_user, :notify_moderators, :spam)
    end

    def auto_action_flag_types
      @auto_action_flag_types ||= flag_types.except(:notify_user, :notify_moderators)
    end

    def public_types
      @public_types ||= types.except(*flag_types.keys << :notify_user)
    end

    def flag_types
      @flag_types ||= types.only(:off_topic, :spam, :inappropriate, :notify_moderators)
    end

    # flags resulting in mod notifications
    def notify_flag_type_ids
      @notify_flag_type_ids ||= types.only(:off_topic, :spam, :inappropriate, :notify_moderators).values
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

