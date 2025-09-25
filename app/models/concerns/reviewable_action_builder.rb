# frozen_string_literal: true

module ReviewableActionBuilder
  extend ActiveSupport::Concern

  # Standard post-actions bundle. Consumers should use the returned
  # bundle value when adding post-focused actions.
  #
  # @param actions [Reviewable::Actions] Actions instance to add the bundle to.
  # @param guardian [Guardian] Guardian instance to check permissions.
  #
  # @return [Reviewable::Actions::Bundle] The created post actions bundle.
  def build_post_actions_bundle(actions, guardian)
    bundle =
      actions.add_bundle(
        "#{id}-post-actions",
        label: "reviewables.actions.post_actions.bundle_title",
      )

    # Always include the no-op action
    build_action(actions, :no_action_post, bundle:)

    return bundle unless target_post

    if target_post.trashed? && guardian.can_recover_post?(target_post)
      build_action(actions, :restore_post, bundle:)
    end

    if target_post.hidden?
      build_action(actions, :unhide_post, bundle:) if !target_post.user_deleted?
    else
      build_action(actions, :hide_post, bundle:)
    end

    if guardian.can_delete_post_or_topic?(target_post)
      build_action(actions, :delete_post, bundle:)
      if target_post.reply_count > 0
        build_action(actions, :delete_post_and_replies, bundle:, confirm: true)
      end
    end

    build_action(actions, :edit_post, bundle:, client_action: "edit")

    build_action(actions, :convert_to_pm, bundle:)

    bundle
  end

  # Standard user-actions bundle and default user actions.
  #
  # @param actions [Reviewable::Actions] Actions instance to add the bundle to.
  # @param guardian [Guardian] Guardian instance to check permissions.
  #
  # @return [Reviewable::Actions::Bundle] The created user actions bundle.
  def build_user_actions_bundle(actions, guardian)
    bundle =
      actions.add_bundle(
        "#{id}-user-actions",
        label: "reviewables.actions.user_actions.bundle_title",
      )

    # Always include the no-op action
    build_action(actions, :no_action_user, bundle:)

    return bundle unless target_user

    if guardian.can_silence_user?(target_user)
      build_action(actions, :silence_user, bundle:, client_action: "silence")
    end

    if guardian.can_suspend?(target_user)
      build_action(actions, :suspend_user, bundle:, client_action: "suspend")
    end

    if guardian.can_delete_user?(target_user)
      build_action(actions, :delete_user, bundle:)
      build_action(actions, :delete_and_block_user, bundle:)
    end

    bundle
  end

  # Build actions for the reviewable based on the current state and guardian permissions.
  #
  # @TODO (reviewable-refresh) Replace this method with {Reviewable#build_actions} once the new UI is fully implemented.
  #
  # @param actions [Reviewable::Actions] Actions instance to add the bundle to.
  # @param guardian [Guardian] Guardian instance to check permissions.
  # @param args [Hash] Additional arguments for building actions.
  #
  # @return [void]
  def build_actions(actions, guardian, args)
    if guardian.can_see_reviewable_ui_refresh?
      build_new_separated_actions(actions, guardian, args)
    else
      build_legacy_combined_actions(actions, guardian, args)
    end
  end

  # Build legacy combined actions for the reviewable.
  #
  # Classes that include this module should implement this method to define
  # the legacy combined actions for their specific reviewable type.
  #
  # @TODO (reviewable-refresh) Remove this method once the new UI is fully implemented.
  #
  # @param actions [Reviewable::Actions] Actions instance to add the bundle to.
  # @param guardian [Guardian] Guardian instance to check permissions.
  # @param args [Hash] Additional arguments for building actions.
  #
  # @return [void]
  def build_legacy_combined_actions(actions, guardian, args)
    raise NotImplementedError, "Including class must implement #build_legacy_combined_actions"
  end

  # Build new separated actions for the reviewable.
  #
  # Classes that include this module should implement this method to define
  # the new separated actions for their specific reviewable type.
  #
  # @TODO (reviewable-refresh) Remove this method once the new UI is fully implemented.
  #
  # @param actions [Reviewable::Actions] Actions instance to add the bundle to.
  # @param guardian [Guardian] Guardian instance to check permissions.
  # @param args [Hash] Additional arguments for building actions.
  #
  # @return [void]
  def build_new_separated_actions(actions, guardian, args)
    raise NotImplementedError, "Including class must implement #build_new_separated_actions"
  end

  # Build a single reviewable action and add it to the provided actions list.
  # This is the canonical API used by both the legacy and refreshed UI code paths.
  #
  # @param actions [Reviewable::Actions] Actions instance to add to.
  # @param id [Symbol] Symbol for the action, used to derive I18n keys.
  # @param icon [String] Optional name of the icon to display with the action. Ignored in the refreshed UI.
  # @param button_class [String] Optional CSS class for buttons in clients that render it.
  # @param bundle [Reviewable::Actions::Bundle] Optional bundle object returned by add_bundle to group actions.
  # @param client_action [String] Optional client-side action identifier (e.g. "edit").
  # @param confirm [Boolean] When true, uses "reviewables.actions.<id>.confirm" for confirm_message.
  # @param require_reject_reason [Boolean] When true, requires a rejection reason for the action.
  #
  # @return [Reviewable::Actions] The updated actions instance.
  def build_action(
    actions,
    id,
    icon: nil,
    button_class: nil,
    bundle: nil,
    client_action: nil,
    confirm: false,
    require_reject_reason: false
  )
    actions.add(id, bundle: bundle) do |action|
      prefix = "reviewables.actions.#{id}"
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

  def perform_no_action_user(performed_by, args)
    create_result(:success, :ignored)
  end

  def perform_no_action_post(performed_by, args)
    create_result(:success, :ignored)
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
    # TODO (reviewable-refresh): This hard-coded post action type needs to make use of the
    # original flag type. See ReviewableFlaggedPost::perform_agree_and_hide for reference.
    target_post.hide!(PostActionType.types[:inappropriate])
    create_result(:success, :rejected, [created_by_id], false)
  end

  def perform_unhide_post(performed_by, _args)
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

  def perform_convert_to_pm(performed_by, _args)
    topic = target_post.topic

    if topic && Guardian.new(performed_by).can_moderate?(topic)
      topic.convert_to_private_message(performed_by)
      create_result(:success, :approved, [created_by_id], false)
    else
      create_result(:failure, :approved) { |r| r.errors = ["Cannot convert to PM"] }
    end
  end

  private

  # Returns the user associated with the reviewable, if applicable.
  # For most reviewables, this will be the user who created the reviewable, though some
  # reviewables may need to implement this method differently (for example, ReviewableUser).
  #
  # @return [User] The user associated with the reviewable.
  def target_user
    try(:target_created_by)
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
