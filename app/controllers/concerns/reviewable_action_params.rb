# frozen_string_literal: true

module ReviewableActionParams
  include PostRevisionParams
  include TagParamLimit

  private

  def reviewable_action_args(reviewable)
    args =
      params
        .permit(
          :reason,
          :message,
          :suspend_until,
          :silenced_till,
          :post_action,
          :post_edit,
          other_user_ids: [],
        )
        .to_h
        .symbolize_keys

    case reviewable
    when ReviewableFlaggedPost
      if params[:action_id] == "agree_and_edit"
        args[:edit] = permitted_post_revision_attributes(params[:edit])
        reject_too_many_tags!(:tags, :original_tags, parameters: params[:edit])
      end
    when ReviewableQueuedPost
      if params[:revise_reason].present?
        args.merge!(
          params
            .permit(:revise_reason, :revise_feedback, :revise_custom_reason)
            .to_h
            .symbolize_keys,
        )
      end
    when ReviewableUser
      args.merge!(params.permit(:reject_reason).to_h.symbolize_keys)
      args[:send_email] = params[:send_email] != "false"
    end

    if reviewable.type_class.respond_to?(:additional_args)
      args.merge!(reviewable.type_class.additional_args(params) || {})
    end
    args
  end
end
