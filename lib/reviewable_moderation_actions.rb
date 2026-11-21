# frozen_string_literal: true

class ReviewableModerationActions
  def self.message_options(classification: nil)
    options = Dsa::AppealInstructions.message_options
    community_rule = classification&.fetch(:community_rule, nil)
    return options unless SiteSetting.dsa_reporting_enabled && community_rule

    options.merge(
      flag_reason_suffix_key: "system_messages.moderation_reason",
      responder_flag_reason_suffix_key: "system_messages.moderation_reason_for_responders",
      ground: community_rule.fetch("ground"),
      explanation: community_rule.fetch("explanation"),
    )
  end

  def initialize(reviewable:, performed_by:, classification: nil)
    @reviewable = reviewable
    @performed_by = performed_by
    @classification = classification

    if performed_by.human?
      scores =
        reviewable.reviewable_scores.pending.where(
          reviewable_score_type: reviewable.post_action_type_view.flag_types.values,
        )
      @flag_source =
        scores.present? && scores.all?(&:automated_detection?) ? "automated" : "community"
    end
  end

  def hide(post_action_type_id:)
    @reviewable.post.hide!(post_action_type_id, message_options: notice_options)
  end

  def delete
    PostDestroyer.new(
      @performed_by,
      @reviewable.post,
      reviewable_id: @reviewable.id,
      message_options: notice_options,
    ).destroy
  end

  def delete_with_replies
    PostDestroyer.delete_with_replies(
      @performed_by,
      @reviewable.post,
      @reviewable.id,
      message_options: notice_options,
    )
  end

  private

  def notice_options
    options = self.class.message_options(classification: @classification)
    options[:flag_source] = @flag_source if @flag_source
    options
  end
end
