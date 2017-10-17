require_dependency 'enum'
require_dependency 'distributed_cache'
require_dependency 'flag_settings'

class PostActionType < ActiveRecord::Base
  after_save :expire_cache
  after_destroy :expire_cache

  include AnonCacheInvalidator

  def expire_cache
    ApplicationSerializer.expire_cache_fragment!("post_action_types")
    ApplicationSerializer.expire_cache_fragment!("post_action_flag_types")
  end

  class << self

    def flag_settings
      unless @flag_settings
        @flag_settings = FlagSettings.new
        @flag_settings.add(
          3,
          :off_topic,
          notify_type: true,
          auto_action_type: true
        )
        @flag_settings.add(
          4,
          :inappropriate,
          topic_type: true,
          notify_type: true,
          auto_action_type: true
        )
        @flag_settings.add(
          8,
          :spam,
          topic_type: true,
          notify_type: true,
          auto_action_type: true
        )
        @flag_settings.add(
          6,
          :notify_user,
          topic_type: true,
          notify_type: true,
          custom_type: true
        )
        @flag_settings.add(
          7,
          :notify_moderators,
          topic_type: true,
          notify_type: true,
          custom_type: true
        )
      end

      @flag_settings
    end

    def replace_flag_settings(settings)
      @flag_settings = settings
      @types = nil
    end

    def ordered
      order('position asc')
    end

    def types
      unless @types
        @types = Enum.new(
          bookmark: 1,
          like: 2,
          vote: 5
        )
        @types.merge!(flag_settings.flag_types)
      end

      @types
    end

    def auto_action_flag_types
      flag_settings.auto_action_types
    end

    def public_types
      @public_types ||= types.except(*flag_types.keys << :notify_user)
    end

    def public_type_ids
      @public_type_ids ||= public_types.values
    end

    def flag_types_without_custom
      flag_settings.without_custom_types
    end

    def flag_types
      flag_settings.flag_types
    end

    # flags resulting in mod notifications
    def notify_flag_type_ids
      notify_flag_types.values
    end

    def notify_flag_types
      flag_settings.notify_types
    end

    def topic_flag_types
      flag_settings.topic_flag_types
    end

    def custom_types
      flag_settings.custom_types
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
