# frozen_string_literal: true

module ReviewableActionParams
  include PostRevisionParams
  include TagParamLimit

  private

  def reviewable_action_args(reviewable)
    args = {}

    if reviewable.type_class.respond_to?(:additional_args)
      args.merge!(reviewable.type_class.additional_args(params) || {})
    end

    if reviewable.is_a?(ReviewableFlaggedPost) && args.key?(:edit)
      edit = args[:edit]
      args[:edit] = permitted_post_revision_attributes(edit)
      reject_too_many_tags!(:tags, :original_tags, parameters: edit)
    end

    plugin_params =
      DiscoursePluginRegistry.reviewable_params.select do |entry|
        reviewable.type == entry[:type].to_s.classify
      end
    args.merge!(params.slice(*plugin_params.map { |entry| entry[:param] }).permit!)

    args
  end
end
