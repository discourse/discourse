# frozen_string_literal: true

module ReviewableFlaggedPostActionParams
  include PostRevisionParams
  include TagParamLimit

  private

  def prepare_reviewable_flagged_post_action_args(args)
    return unless args.key?(:post_revision)

    revision = args[:post_revision]
    args[:post_revision] = permitted_post_revision_attributes(revision)
    reject_too_many_tags!(:tags, :original_tags, parameters: revision)
  end
end
