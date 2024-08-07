# frozen_string_literal: true

class FlagSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :name_key,
             :description,
             :short_description,
             :applies_to,
             :position,
             :require_message,
             :enabled,
             :is_flag,
             :applies_to,
             :is_used

  def i18n_prefix
    "#{@options[:target] || "post_action"}_types.#{object.name_key}"
  end

  def name
    # system flags are using i18n translations when custom flags are using value entered by admin
    I18n.t("#{i18n_prefix}.title", default: object.name)
  end

  def description
    I18n.t("#{i18n_prefix}.description", default: object.description)
  end

  def short_description
    I18n.t("#{i18n_prefix}.short_description", base_path: Discourse.base_path, default: "")
  end

  def is_flag
    !object.score_type && object.id != 2
  end

  def is_used
    PostAction.exists?(post_action_type_id: object.id) ||
      ReviewableScore.exists?(reviewable_score_type: object.id)
  end

  def applies_to
    Array.wrap(object.applies_to)
  end
end
