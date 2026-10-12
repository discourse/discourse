# frozen_string_literal: true

module ReviewableActionParams
  private

  def reviewable_action_args(reviewable)
    args = {}

    if reviewable.type_class.respond_to?(:additional_args)
      args.merge!(reviewable.type_class.additional_args(params) || {})
    end

    preparation_method = "prepare_#{reviewable.type.underscore}_action_args"
    send(preparation_method, args) if respond_to?(preparation_method, true)

    plugin_params =
      DiscoursePluginRegistry.reviewable_params.select do |entry|
        reviewable.type == entry[:type].to_s.classify
      end
    args.merge!(params.slice(*plugin_params.map { |entry| entry[:param] }).permit!)

    args
  end
end
