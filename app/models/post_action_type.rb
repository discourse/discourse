require_dependency 'enum'

class PostActionType < ActiveRecord::Base
  attr_accessible :id, :is_flag, :name_key, :icon

  class << self
    def ordered
      order('position asc').all
    end

    def types
      @types ||= Enum.new(:bookmark, :like, :off_topic, :inappropriate, :vote,
                          :notify_user, :notify_moderators, :spam)
    end

    def auto_action_flag_types
      @auto_action_flag_types ||= flag_types.except(:notify_user, :notify_moderators)
    end

    def flag_types
      @flag_types ||= types.only(:off_topic, :spam, :inappropriate, :notify_user, :notify_moderators)
    end

    # flags resulting in mod notifications
    def notify_flag_types
      @notify_flag_types ||= types.only(:off_topic, :spam, :inappropriate, :notify_moderators)
    end

    def is_flag?(sym)
      flag_types.valid?(sym)
    end
  end
end
