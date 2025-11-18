# frozen_string_literal: true

module ReviewableActionBuilder
  extend ActiveSupport::Concern

  attr_accessor :actions, :guardian, :action_args

  # Standard post-actions bundle. Consumers should use the returned
  # bundle value when adding post-focused actions.
  #
  # @return [Reviewable::Actions::Bundle] The created post actions bundle.
  def build_post_actions_bundle
    bundle_actions = { no_action_post: {} }
    if target_post
      if target_post.trashed? && @guardian.can_recover_post?(target_post)
        bundle_actions[:restore_post] = {}
      end

      if target_post.hidden?
        bundle_actions[:unhide_post] = {} if !target_post.user_deleted?
      else
        bundle_actions[:hide_post] = {}
      end

      if @guardian.can_delete_post_or_topic?(target_post)
        bundle_actions[:delete_post] = {}
        bundle_actions[:delete_post_and_replies] = { confirm: true } if target_post.reply_count > 0
      end

      bundle_actions[:edit_post] = { client_action: "edit" }

      bundle_actions[:convert_to_pm] = {}
    end

    build_bundle(
      "#{id}-post-actions",
      "reviewables.actions.post_actions.bundle_title",
      bundle_actions,
      source: "core",
    )
  end

  # Standard user-actions bundle and default user actions.
  #
  # @return [Reviewable::Actions::Bundle] The created user actions bundle.
  def build_user_actions_bundle
    bundle_actions = { no_action_user: {} }
    if target_user
      if @guardian.can_silence_user?(target_user)
        bundle_actions[:silence_user] = { client_action: "silence" }
      end

      if @guardian.can_suspend?(target_user)
        bundle_actions[:suspend_user] = { client_action: "suspend" }
      end

      if @guardian.can_delete_user?(target_user)
        bundle_actions[:delete_user] = {}
        bundle_actions[:delete_and_block_user] = {}
      end
    end

    build_bundle(
      "#{id}-user-actions",
      "reviewables.actions.user_actions.bundle_title",
      bundle_actions,
      source: "core",
    )
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
    @actions = actions
    @guardian = guardian
    @action_args = args

    if guardian.can_see_reviewable_ui_refresh? && !SiteSetting.reviewable_old_moderator_actions
      build_new_separated_actions
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
  # @return [void]
  def build_new_separated_actions
    raise NotImplementedError, "Including class must implement #build_new_separated_actions"
  end

  # Build a bundle of actions and add it to the provided actions list.
  #
  # @param id [String] ID for the bundle, used to derive I18n keys.
  # @param label [String] I18n key for the bundle label.
  # @param bundle_actions [Hash] Hash of action IDs and optional params to pass to build_action.
  # @option bundle_actions [Symbol] :client_action Optional client-side action identifier (e.g. "edit").
  # @option bundle_actions [Symbol] :confirm When true, uses "reviewables.actions.<id>.confirm" for confirm_message.
  # @option bundle_actions [Symbol] :require_reject_reason When true, requires a rejection reason for the action.
  # @param source [String] Optional source string for namespacing I18n keys. Will default to `type_source`.
  #
  # @return [Reviewable::Actions::Bundle] The created bundle.
  def build_bundle(id, label, bundle_actions = {}, source: nil)
    bundle = @actions.add_bundle(id, label:)
    bundle_actions.each do |action_id, action_params|
      build_action(@actions, action_id, bundle:, **action_params || {}, source:)
    end
    bundle
  end

  # Build a single reviewable action and add it to the provided actions list.
  # This is the canonical API used by both the legacy and refreshed UI code paths.
  #
  # @param actions [Reviewable::Actions] Actions instance to add to.
  # @param id [Symbol] Symbol for the action, used to derive I18n keys.
  # @param icon [String] Optional name of the icon to display with the action. Ignored in the refreshed UI.
  # @param button_class [String] Optional CSS class for buttons in clients that render it. Ignored in the refreshed UI.
  # @param bundle [Reviewable::Actions::Bundle] Optional bundle object returned by add_bundle to group actions.
  # @param client_action [String] Optional client-side action identifier (e.g. "edit").
  # @param confirm [Boolean] When true, uses "reviewables.actions.<id>.confirm" for confirm_message.
  # @param require_reject_reason [Boolean] When true, requires a rejection reason for the action.
  # @param source [String] Optional source string for namespacing I18n keys. Will default to `type_source`.
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
    # TODO (reviewable-refresh): Implement convert to PM logic
    create_result(:success, :rejected, [created_by_id], false)
  end

  # Calculate the final reviewable status based on the action logs. This method
  # assumes that all_bundles_actioned? has already returned true.
  #
  # @return [Symbol] The calculated final status (:ignored, :rejected, :approved, or :pending)
  def calculate_final_status_from_logs
    statuses = reviewable_action_logs.pluck(:status).uniq

    return :pending if statuses.empty?

    ignored_value = Reviewable.statuses["ignored"]
    rejected_value = Reviewable.statuses["rejected"]
    approved_value = Reviewable.statuses["approved"]

    return :ignored if statuses.all? { |s| s == "ignored" || s == ignored_value }
    return :rejected if statuses.all? { |s| s == "rejected" || s == rejected_value }
    return :approved if statuses.any? { |s| s == "approved" || s == approved_value }

    :pending
  end

  # Check if all action bundles have been addressed with at least one action.
  #
  # @param guardian [Guardian] The guardian to check permissions for.
  # @param args [Hash] Additional arguments for building actions.
  #
  # @return [Boolean] True if all bundles have at least one logged action.
  def all_bundles_actioned?(guardian, args = {})
    actions = actions_for(guardian, args)
    # Extract bundle types from bundle IDs (e.g., "8311-post-actions" -> "post-actions")
    current_bundle_types = actions.bundles.map { |b| b.id.split("-", 2).last }
    logged_bundle_types = reviewable_action_logs.pluck(:bundle).uniq.compact

    # Check if at least one action from each bundle type has been logged
    current_bundle_types.all? { |type| logged_bundle_types.include?(type) }
  end

  # Override the Reviewable#perform method to add action logging, and to handle deferred finalization
  # when using the new reviewable UI refresh.
  #
  # @param performed_by [User] The user performing the action.
  # @param action_id [Symbol] The action being performed.
  # @param args [Hash] Additional arguments for the action.
  #
  # @return [Reviewable::PerformResult] The result of the action.
  def perform(performed_by, action_id, args = nil)
    args ||= {}
    guardian = args[:guardian] || Guardian.new(performed_by)
    use_deferred_transitions =
      guardian.can_see_reviewable_ui_refresh? && !SiteSetting.reviewable_old_moderator_actions

    # Find which bundle this action belongs to BEFORE executing
    # (actions may change after execution, e.g., hide_post -> unhide_post)
    actions = actions_for(guardian, args)
    bundle_type = nil
    actions.bundles.each do |bundle|
      if bundle.actions.any? { |a| a.server_action.to_s == action_id.to_s }
        # Extract bundle type from bundle ID (e.g., "8311-post-actions" -> "post-actions")
        bundle_type = bundle.id.split("-", 2).last
        break
      end
    end

    # For old UI actions that aren't in the new separated bundles, use a default bundle
    bundle_type ||= "legacy-actions"

    # Execute the action but skip automatic finalization if using deferred transitions
    args_for_super = args.dup
    args_for_super[:skip_finalization] = true if use_deferred_transitions
    result = super(performed_by, action_id, args_for_super)

    if result.success? && result.transition_to
      reviewable_action_logs.create!(
        action_key: action_id.to_s,
        status: result.transition_to,
        performed_by: performed_by,
        bundle: bundle_type,
      )
    end

    if use_deferred_transitions
      if all_bundles_actioned?(guardian, args)
        finalize_perform_result(
          result,
          performed_by,
          guardian,
          transition_to_status: calculate_final_status_from_logs,
        )
      end
    else
      finalize_perform_result(result, performed_by, guardian) unless args[:skip_finalization]
    end

    result
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
