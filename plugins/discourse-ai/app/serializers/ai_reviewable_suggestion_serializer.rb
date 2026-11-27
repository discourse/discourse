# frozen_string_literal: true

class AiReviewableSuggestionSerializer < ApplicationSerializer
  EXCERPT_LENGTH = 240

  attributes :id,
             :type,
             :version,
             :created_at,
             :title,
             :excerpt,
             :username,
             :reasons,
             :confidence,
             :action,
             :blocked_reason

  def suggested_action
    return @suggested_action if defined?(@suggested_action)

    suggestion = object.ai_reviewable_suggestion
    return @suggested_action = nil unless suggestion&.actionable?

    name = suggestion.action_name
    @suggested_action = object.actions_for(scope).to_a.find { |action| action.action_name == name }
  end

  def title
    object.topic&.title.presence || object.payload&.dig("title").presence
  end

  def excerpt
    target = object.target
    text =
      target.try(:raw).presence || target.try(:message).presence ||
        object.payload&.values_at("raw", "message", "bio")&.find(&:present?)
    text.to_s.squish.truncate(EXCERPT_LENGTH).presence
  end

  def username
    object.target_created_by&.username
  end

  def reasons
    object
      .scores_for_decision
      .map(&:reviewable_score_type)
      .uniq
      .filter_map { |type| ReviewableScore.type_title(ReviewableScore.types.key(type)) }
  end

  def confidence
    object.ai_reviewable_suggestion.confidence
  end

  def action
    {
      server_action: suggested_action.server_action,
      label: I18n.t(suggested_action.label),
      destructive:
        suggested_action.confirm_destructive.present? ||
          suggested_action.button_class.to_s.include?("danger"),
    }
  end

  # Bulk applying sends no extra input, so anything the single-item flow would
  # prompt for has to be handled from the item itself.
  def blocked_reason
    return "needs_input" if needs_input?
    return if SiteSetting.reviewable_claiming == "disabled" || object.topic_id.blank?

    claimed_user_id = @options[:claimed_user_ids][object.topic_id]
    if claimed_user_id.blank?
      "must_claim" if SiteSetting.reviewable_claiming == "required"
    elsif claimed_user_id != scope.user.id
      "claimed_by_other"
    end
  end

  def include_blocked_reason?
    blocked_reason.present?
  end

  private

  def needs_input?
    suggested_action.client_action.present? || suggested_action.require_reject_reason.present? ||
      suggested_action.custom_modal.present? ||
      (suggested_action.dsa_classification_required && DsaStatementOfRecord.classification_enabled?)
  end
end
