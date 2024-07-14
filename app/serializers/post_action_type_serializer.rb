# frozen_string_literal: true

class PostActionTypeSerializer < ApplicationSerializer
  attributes(
    :id,
    :name_key,
    :name,
    :description,
    :short_description,
    :is_flag,
    :is_custom_flag,
    :enabled,
    :applies_to,
    :is_used,
  )

  include ConfigurableUrls

  def is_custom_flag
    !!PostActionType.custom_types[object.id]
  end

  def is_flag
    !!PostActionType.flag_types[object.id]
  end

  def name
    i18n("title", default: object.class.names[object.id])
  end

  def description
    i18n(
      "description",
      vars: {
        tos_url:,
        base_path: Discourse.base_path,
      },
      default: object.class.descriptions[object.id],
    )
  end

  def short_description
    i18n("short_description", vars: { tos_url: tos_url, base_path: Discourse.base_path })
  end

  def name_key
    PostActionType.types[object.id].to_s
  end

  def enabled
    !!PostActionType.enabled_flag_types[object.id]
  end

  def applies_to
    Array.wrap(PostActionType.applies_to[object.id])
  end

  def is_used
    PostAction.exists?(post_action_type_id: object.id) ||
      ReviewableScore.exists?(reviewable_score_type: object.id)
  end

  protected

  def i18n(field, default: nil, vars: nil)
    key = "post_action_types.#{name_key}.#{field}"
    vars ? I18n.t(key, vars, default: default) : I18n.t(key, default: default)
  end
end
