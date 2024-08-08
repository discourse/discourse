# frozen_string_literal: true

class PostActionType < ActiveRecord::Base
  POST_ACTION_TYPE_ALL_FLAGS_KEY = "post_action_type_all_flags"
  POST_ACTION_TYPE_PUBLIC_TYPE_IDS_KEY = "post_action_public_type_ids"

  after_save { expire_cache if !skip_expire_cache_callback }
  after_destroy { expire_cache if !skip_expire_cache_callback }

  attr_accessor :skip_expire_cache_callback

  include AnonCacheInvalidator

  def expire_cache
    Discourse.cache.keys("post_action_types_*").each { |key| Discourse.redis.del(key) }
    Discourse.cache.keys("post_action_flag_types_*").each { |key| Discourse.redis.del(key) }
    Discourse.cache.delete(POST_ACTION_TYPE_ALL_FLAGS_KEY)
    Discourse.cache.delete(POST_ACTION_TYPE_PUBLIC_TYPE_IDS_KEY)
  end

  class << self
    attr_reader :flag_settings

    def initialize_flag_settings
      @flag_settings = FlagSettings.new
    end

    def replace_flag_settings(settings)
      Discourse.deprecate("Flags should not be replaced. Insert custom flags as database records.")
      @flag_settings = settings || FlagSettings.new
    end

    def types
      if overridden_by_plugin_or_skipped_db?
        return Enum.new(like: LIKE_POST_ACTION_ID).merge!(flag_settings.flag_types)
      end
      Enum.new(like: LIKE_POST_ACTION_ID).merge(flag_types)
    end

    def reload_types
      @flag_settings = FlagSettings.new
      PostActionType.new.expire_cache
      ReviewableScore.reload_types
    end

    def overridden_by_plugin_or_skipped_db?
      flag_settings.flag_types.present? || GlobalSetting.skip_db?
    end

    def all_flags
      Discourse
        .cache
        .fetch(PostActionType::POST_ACTION_TYPE_ALL_FLAGS_KEY) do
          Flag
            .unscoped
            .order(:position)
            .pluck(ATTRIBUTE_NAMES)
            .map { |attributes| ATTRIBUTE_NAMES.zip(attributes).to_h }
        end
    end

    def auto_action_flag_types
      return flag_settings.auto_action_types if overridden_by_plugin_or_skipped_db?
      flag_enum(all_flags.select { |flag| flag[:auto_action_type] })
    end

    def public_types
      types.except(*flag_types.keys << :notify_user)
    end

    def public_type_ids
      Discourse
        .cache
        .fetch(PostActionType::POST_ACTION_TYPE_PUBLIC_TYPE_IDS_KEY) { public_types.values }
    end

    def flag_types_without_additional_message
      return flag_settings.without_additional_message_types if overridden_by_plugin_or_skipped_db?
      flag_enum(all_flags.reject { |flag| flag[:require_message] })
    end

    def flag_types
      return flag_settings.flag_types if overridden_by_plugin_or_skipped_db?
      flag_enum(all_flags.reject { |flag| flag[:score_type] })
    end

    def score_types
      return flag_settings.flag_types if overridden_by_plugin_or_skipped_db?
      flag_enum(all_flags.filter { |flag| flag[:score_type] })
    end

    # flags resulting in mod notifications
    def notify_flag_type_ids
      notify_flag_types.values
    end

    def notify_flag_types
      return flag_settings.notify_types if overridden_by_plugin_or_skipped_db?
      flag_enum(all_flags.select { |flag| flag[:notify_type] })
    end

    def topic_flag_types
      if overridden_by_plugin_or_skipped_db?
        flag_settings.topic_flag_types
      else
        flag_enum(all_flags.select { |flag| flag[:applies_to].include?("Topic") })
      end
    end

    def disabled_flag_types
      flag_enum(all_flags.reject { |flag| flag[:enabled] })
    end

    def additional_message_types
      return flag_settings.additional_message_types if overridden_by_plugin_or_skipped_db?
      flag_enum(all_flags.select { |flag| flag[:require_message] })
    end

    def names
      all_flags.reduce({}) do |acc, f|
        acc[f[:id]] = f[:name]
        acc
      end
    end

    def descriptions
      all_flags.reduce({}) do |acc, f|
        acc[f[:id]] = f[:description]
        acc
      end
    end

    def applies_to
      all_flags.reduce({}) do |acc, f|
        acc[f[:id]] = f[:applies_to]
        acc
      end
    end

    def is_flag?(sym)
      flag_types.valid?(sym)
    end

    private

    def flag_enum(scope)
      Enum.new(
        scope.reduce({}) do |acc, f|
          acc[f[:name_key].to_sym] = f[:id]
          acc
        end,
      )
    end
  end

  initialize_flag_settings
end

# == Schema Information
#
# Table name: post_action_types
#
#  name_key            :string(50)       not null
#  is_flag             :boolean          default(FALSE), not null
#  icon                :string(20)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  id                  :integer          not null, primary key
#  position            :integer          default(0), not null
#  score_bonus         :float            default(0.0), not null
#  reviewable_priority :integer          default(0), not null
#
