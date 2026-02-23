# frozen_string_literal: true

module ReviewableActionBuilder
  extend ActiveSupport::Concern

  attr_accessor :actions, :guardian, :action_args

  def build_actions(actions, guardian, args)
    @actions = actions
    @guardian = guardian
    @action_args = args

    # For backward compatibility with plugins that override build_legacy_combined_actions
    if respond_to?(:build_legacy_combined_actions)
      build_legacy_combined_actions(actions, guardian, args)
    else
      build_combined_actions(actions, guardian, args)
    end
  end

  def build_combined_actions(actions, guardian, args)
    raise NotImplementedError, "Including class must implement #build_combined_actions"
  end

  def build_bundle(id, label, bundle_actions = {}, source: nil)
    bundle = @actions.add_bundle(id, label:)
    bundle_actions.each do |action_id, action_params|
      build_action(@actions, action_id, bundle:, **action_params || {}, source:)
    end
    bundle
  end

  def build_action(
    actions,
    id,
    icon: nil,
    button_class: nil,
    bundle: nil,
    client_action: nil,
    confirm: false,
    require_reject_reason: false,
    source: nil
  )
    actions.add(id, bundle: bundle) do |action|
      source ||= type_source
      if source == "core"
        prefix = "reviewables.actions.#{id}"
      else
        prefix = "#{source.underscore}.reviewables.actions.#{id}"
      end

      action.icon = icon if icon
      action.button_class = button_class if button_class
      action.label = "#{prefix}.title"
      action.description = "#{prefix}.description"
      action.client_action = client_action if client_action
      action.confirm_message = "#{prefix}.confirm" if confirm
      action.completed_message = "#{prefix}.complete"
      action.require_reject_reason = require_reject_reason
    end
  end

  def perform_silence_user(performed_by, args)
    create_result(:success, :rejected)
  end

  def perform_suspend_user(performed_by, args)
    create_result(:success, :rejected)
  end

  def perform_delete_user(performed_by, args, &)
    delete_user(target_user, delete_opts, performed_by) if target_user
    create_result(:success, :rejected, [], false, &)
  end

  def perform_delete_and_block_user(performed_by, args, &)
    delete_options = delete_opts
    delete_options.merge!(block_email: true, block_ip: true) if Rails.env.production?

    delete_user(target_user, delete_options, performed_by) if target_user
    create_result(:success, :rejected, [], false, &)
  end

  def perform_delete_post(performed_by, _args)
    PostDestroyer.new(performed_by, target_post, reviewable: self).destroy
    create_result(:success, :rejected, [created_by_id], false)
  end

  def perform_hide_post(performed_by, _args)
    target_post.hide!(PostActionType.types[:inappropriate])
    create_result(:success, :rejected, [created_by_id], false)
  end

  def perform_unhide_post(performed_by, _args)
    target_post.acting_user = performed_by
    target_post.unhide!
    create_result(:success, :approved, [created_by_id], false)
  end

  def perform_restore_post(performed_by, _args)
    PostDestroyer.new(performed_by, target_post).recover
    create_result(:success, :approved, [created_by_id], false)
  end

  def perform_edit_post(performed_by, _args)
    # This is handled client-side, just transition the state
    create_result(:success, :approved, [created_by_id], false)
  end

  private

  # Returns the user associated with the reviewable, if applicable.
  # For most reviewables, this will be the user who created the reviewable target.
  #
  # @return [User] The user associated with the reviewable.
  def target_user
    if target_type == "User"
      try(:target)
    else
      try(:target_created_by)
    end
  end

  # Returns the post associated with the reviewable, if applicable.
  # This method assumes that the including class has a `target` that is a Post or
  # a `target_id` that can be used to look up the Post.
  #
  # @return [Post, nil] The post associated with the reviewable, or nil if not found.
  def target_post
    @post ||=
      if defined?(target) && target.is_a?(Post)
        target
      elsif defined?(target_id)
        Post.with_deleted.find_by(id: target_id)
      end
  end

  # Options for deleting a user, used by perform_delete_user and perform_delete_and_block_user.
  def delete_opts
    {
      delete_posts: true,
      prepare_for_destroy: true,
      block_urls: true,
      delete_as_spammer: true,
      context: "review",
    }
  end

  def delete_user(user, delete_options, performed_by)
    email = user.email

    UserDestroyer.new(performed_by).destroy(user, delete_options)

    message = UserNotifications.account_deleted(email, self)
    Email::Sender.new(message, :account_deleted).send
  end

  def map_reviewable_status_to_flag_status(status)
    case status
    when :approved
      :agreed
    when :rejected
      :disagreed
    else
      status
    end
  end

  # Create a result object.
  #
  # @param status [Symbol] The status of the result.
  # @param transition_to [Symbol] The state to transition to.
  # @param recalculate_score [Boolean] Whether to recalculate the score.
  # @yield [result] The result object.
  #
  # @return [Reviewable::PerformResult] The created result object.
  def create_result(status, transition_to = nil, flagging_user_ids = [], recalculate_score = true)
    result = Reviewable::PerformResult.new(self, status)
    result.transition_to = transition_to
    if flagging_user_ids.any? && target_post
      result.update_flag_stats = {
        status: map_reviewable_status_to_flag_status(transition_to),
        user_ids: flagging_user_ids,
      }
      result.recalculate_score = recalculate_score
    end
    yield result if block_given?
    result
  end
end
