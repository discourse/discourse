# frozen_string_literal: true

class ReviewableModerationActions
  def self.message_options(classification: nil)
    options = Dsa::AppealInstructions.message_options
    rule = selected_rule(classification)
    return options unless rule

    options.merge(
      flag_reason_suffix_key: "system_messages.moderation_reason",
      responder_flag_reason_suffix_key: "system_messages.moderation_reason_for_responders",
      ground: rule.fetch("ground"),
      explanation: rule.fetch("explanation"),
    )
  end

  def self.rule_paragraph(
    classification:,
    locale:,
    key: "system_messages.account_moderation_reason"
  )
    rule = selected_rule(classification)
    if rule
      I18n.t(key, locale:, ground: rule.fetch("ground"), explanation: rule.fetch("explanation"))
    end
  end

  def self.selected_rule(classification)
    classification&.fetch(:community_rule, nil) if SiteSetting.dsa_reporting_enabled
  end
  private_class_method :selected_rule

  def initialize(post:, reviewable_id:, performed_by:, classification: nil)
    @post = post
    @reviewable_id = reviewable_id
    @performed_by = performed_by
    @classification = classification
  end

  def hide(post_action_type_id:)
    @post.hide!(post_action_type_id, message_options: notice_options)
  end

  def delete
    PostDestroyer.new(
      @performed_by,
      @post,
      reviewable_id: @reviewable_id,
      message_options: notice_options,
    ).destroy
  end

  def delete_with_replies
    PostDestroyer.delete_with_replies(
      @performed_by,
      @post,
      @reviewable_id,
      message_options: notice_options,
    )
  end

  private

  def notice_options
    self.class.message_options(classification: @classification)
  end
end
