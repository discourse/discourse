# frozen_string_literal: true

class PostActionTypeView
  ATTRIBUTE_NAMES = %i[
    id
    name
    name_key
    description
    notify_type
    auto_action_type
    require_message
    applies_to
    position
    enabled
    score_type
  ].freeze

  def all_flags
    @all_flags ||=
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

  def flag_settings
    @flag_settings ||= PostActionType.flag_settings
  end

  def types
    if overridden_by_plugin_or_skipped_db?
      return Enum.new(like: PostActionType::LIKE_POST_ACTION_ID).merge!(flag_settings.flag_types)
    end
    Enum.new(like: PostActionType::LIKE_POST_ACTION_ID).merge(flag_types)
  end

  def overridden_by_plugin_or_skipped_db?
    flag_settings.flag_types.present? || GlobalSetting.skip_db?
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
    flag_enum(flags.reject { |flag| flag[:require_message] })
  end

  def flags
    all_flags.reject do |flag|
      flag[:score_type] || flag[:id] == PostActionType::LIKE_POST_ACTION_ID
    end
  end

  def flag_types
    return flag_settings.flag_types if overridden_by_plugin_or_skipped_db?
    flag_enum(flags)
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
