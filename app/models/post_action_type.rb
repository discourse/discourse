require_dependency 'enum'

class PostActionType < ActiveRecord::Base
  attr_accessible :id, :is_flag, :name_key, :icon

  class << self
    def ordered
      order('position asc').all
    end

    def types
      @types ||= Enum.new(:bookmark, :like, :off_topic, :inappropriate, :vote,
                          :custom_flag, :spam)
    end

    def auto_action_flag_types
      @auto_action_flag_types ||= flag_types.except(:custom_flag)
    end

    def flag_types
      @flag_types ||= types.only(:off_topic, :spam, :inappropriate, :custom_flag)
    end

    def is_flag?(sym)
      flag_types.valid?(sym)
    end
  end
end
