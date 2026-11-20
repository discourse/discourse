# frozen_string_literal: true

class ReviewableModerationActions
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
    community_rule = Dsa::ModerationGuideline.selected_rule(@classification)
    community_rule ? { community_rule: } : {}
  end
end
