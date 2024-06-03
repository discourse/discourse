# frozen_string_literal: true

class PostActionType < ActiveRecord::Base
  after_save :expire_cache
  after_destroy :expire_cache

  include AnonCacheInvalidator

  def expire_cache
    ApplicationSerializer.expire_cache_fragment!(/\Apost_action_types_/)
    ApplicationSerializer.expire_cache_fragment!(/\Apost_action_flag_types_/)
  end

  DiscourseEvent.on(:reload_post_action_types) { self.reload_types }

  class << self
    attr_reader :flag_settings

    def initialize_flag_settings
      @flag_settings = FlagSettings.new
    end

    def replace_flag_settings(settings)
      Discourse.deprecate("Flags should not be replaced. Insert custom flags as database records.")
      @flag_settings = settings || FlagSettings.new
      @all_flags = nil
    end

    def types
      if overridden_by_plugin_or_skipped_db?
        return Enum.new(like: 2).merge!(flag_settings.flag_types)
      end
      Enum.new(like: 2).merge(flag_types)
    end

    def reload_types
      @all_flags = nil
      @flag_settings = FlagSettings.new
      ReviewableScore.reload_types
      PostActionType.new.expire_cache
    end

    def overridden_by_plugin_or_skipped_db?
      flag_settings.flag_types.present? || GlobalSetting.skip_db?
    end

    def all_flags
      @all_flags ||= Flag.unscoped.order(:position).all
    end

    def auto_action_flag_types
      return flag_settings.auto_action_types if overridden_by_plugin_or_skipped_db?
      flag_enum(all_flags.select(&:auto_action_type))
    end

    def public_types
      types.except(*flag_types.keys << :notify_user)
    end

    def public_type_ids
      @public_type_ids ||= public_types.values
    end

    def flag_types_without_custom
      return flag_settings.without_custom_types if overridden_by_plugin_or_skipped_db?
      flag_enum(all_flags.reject(&:custom_type))
    end

    def flag_types
      return flag_settings.flag_types if overridden_by_plugin_or_skipped_db?

      # Once replace_flag API is fully deprecated, then we can drop respond_to. It is needed right now for migration to be evaluated.
      # TODO (krisk)
      flag_enum(all_flags.reject { |flag| flag.respond_to?(:score_type) && flag.score_type })
    end

    def score_types
      return flag_settings.flag_types if overridden_by_plugin_or_skipped_db?

      # Once replace_flag API is fully deprecated, then we can drop respond_to. It is needed right now for migration to be evaluated.
      # TODO (krisk)
      flag_enum(all_flags.filter { |flag| flag.respond_to?(:score_type) && flag.score_type })
    end

    # flags resulting in mod notifications
    def notify_flag_type_ids
      notify_flag_types.values
    end

    def notify_flag_types
      return flag_settings.notify_types if overridden_by_plugin_or_skipped_db?
      flag_enum(all_flags.select(&:notify_type))
    end

    def topic_flag_types
      if overridden_by_plugin_or_skipped_db?
        flag_settings.topic_flag_types
      else
        flag_enum(all_flags.select { |flag| flag.applies_to?("Topic") })
      end
    end

    def disabled_flag_types
      flag_enum(all_flags.reject(&:enabled))
    end

    def enabled_flag_types
      flag_enum(all_flags.filter(&:enabled))
    end

    def custom_types
      return flag_settings.custom_types if overridden_by_plugin_or_skipped_db?
      flag_enum(all_flags.select(&:custom_type))
    end

    def names
      all_flags.pluck(:id, :name).to_h
    end

    def is_flag?(sym)
      flag_types.valid?(sym)
    end

    private

    def flag_enum(scope)
      Enum.new(scope.map { |flag| [flag.name_key.to_sym, flag.id] }.to_h)
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
