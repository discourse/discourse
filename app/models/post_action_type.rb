# frozen_string_literal: true

class PostActionType < ActiveRecord::Base
  POST_ACTION_TYPE_ALL_FLAGS_KEY = "post_action_type_all_flags"
  POST_ACTION_TYPE_PUBLIC_TYPE_IDS_KEY = "post_action_public_type_ids"
  LIKE_POST_ACTION_ID = 2

  after_save { expire_cache if !skip_expire_cache_callback }
  after_destroy { expire_cache if !skip_expire_cache_callback }

  attr_accessor :skip_expire_cache_callback

  include AnonCacheInvalidator

  def expire_cache
    Discourse.cache.redis.del(
      *I18n.available_locales.map do |locale|
        Discourse.cache.normalize_key("post_action_types_#{locale}")
      end,
      *I18n.available_locales.map do |locale|
        Discourse.cache.normalize_key("post_action_flag_types_#{locale}")
      end,
      Discourse.cache.normalize_key(POST_ACTION_TYPE_ALL_FLAGS_KEY),
      Discourse.cache.normalize_key(POST_ACTION_TYPE_PUBLIC_TYPE_IDS_KEY),
    )
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

    def reload_types
      @flag_settings = FlagSettings.new
      PostActionType.new.expire_cache
      ReviewableScore.reload_types
    end

    %i[
      expire_cache
      all_flags
      types
      overridden_by_plugin_or_skipped_db?
      auto_action_flag_types
      public_types
      public_type_ids
      flag_types_without_additional_message
      flags
      flag_types
      score_types
      notify_flag_type_ids
      notify_flag_types
      topic_flag_types
      disabled_flag_types
      additional_message_types
      names
      descriptions
      applies_to
      is_flag?
    ].each do |method_name|
      define_method(method_name) { |*args| PostActionTypeView.new.send(method_name, *args) }
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
