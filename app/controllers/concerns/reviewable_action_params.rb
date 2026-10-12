# frozen_string_literal: true

module ReviewableActionParams
  include PostRevisionParams
  include TagParamLimit

  private

  def reviewable_action_args(reviewable)
    args = {}

    if reviewable.type_class.respond_to?(:additional_args)
      additional_args =
        reviewable
          .type_class
          .additional_args(params) do |revision|
            attributes = permitted_post_revision_attributes(revision)
            reject_too_many_tags!(:tags, :original_tags, parameters: revision)

            attributes
          end

      args.merge!(additional_args || {})
    end

    plugin_params =
      DiscoursePluginRegistry.reviewable_params.select do |entry|
        reviewable.type == entry[:type].to_s.classify
      end
    args.merge!(params.slice(*plugin_params.map { |entry| entry[:param] }).permit!)

    args
  end
end
