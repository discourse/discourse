# frozen_string_literal: true

class PostActionTypeSerializer < ApplicationSerializer
  attributes(
    :id,
    :name_key,
    :name,
    :description,
    :short_description,
    :is_flag,
    :require_message,
    :enabled,
    :applies_to,
    :is_used,
  )

  include ConfigurableUrls

  def post_action_type_view
    @post_action_type_view ||= PostActionTypeView.new
  end

  def require_message
    !!post_action_type_view.additional_message_types[object.id]
  end

  def is_flag
    !!post_action_type_view.flag_types[object.id]
  end

  def name
    i18n("title", default: object.class.names[object.id])
  end

  def description
    i18n(
      "description",
      tos_url:,
      base_path: Discourse.base_path,
      default: object.class.descriptions[object.id],
    )
  end

  def short_description
    i18n("short_description", tos_url:, base_path: Discourse.base_path, default: "")
  end

  def name_key
    post_action_type_view.types[object.id].to_s
  end

  def enabled
    # flags added by API are always enabled
    true
  end

  def applies_to
    Flag.valid_applies_to_types
  end

  def is_used
    PostAction.exists?(post_action_type_id: object.id) ||
      ReviewableScore.exists?(reviewable_score_type: object.id)
  end

  private

  def i18n(field, **args)
    key = "#{i18n_prefix}.#{name_key}.#{field}"
    I18n.t(key, **args)
  end

  def i18n_prefix
    "post_action_types"
  end
end
