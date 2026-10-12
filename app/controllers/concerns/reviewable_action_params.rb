# frozen_string_literal: true

module ReviewableActionParams
  include PostRevisionParams
  include TagParamLimit

  private

  def reviewable_action_args(reviewable)
    declared_params = reviewable.type_class.action_params
    args = params.permit(*declared_params).to_h.symbolize_keys
    args[:send_email] = params[:send_email] != "false" if declared_params.include?(:send_email)

    if declared_params.include?(:edit) && params.key?(:edit)
      args[:edit] = permitted_post_revision_attributes(params[:edit])
      reject_too_many_tags!(:tags, :original_tags, parameters: params[:edit])
    end

    if reviewable.type_class.respond_to?(:additional_args)
      args.merge!(reviewable.type_class.additional_args(params) || {})
    end

    plugin_params =
      DiscoursePluginRegistry.reviewable_params.select do |entry|
        reviewable.type == entry[:type].to_s.classify
      end
    args.merge!(params.slice(*plugin_params.map { |entry| entry[:param] }).permit!)

    args
  end
end
