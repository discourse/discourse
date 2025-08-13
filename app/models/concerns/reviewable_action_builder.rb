# frozen_string_literal: true

module ReviewableActionBuilder
  extend ActiveSupport::Concern

  FLAGGABLE = false

  # Standard user-actions bundle and default user actions.
  # Callers should gate invocation (e.g., only when
  # target_created_by is present, or only while pending).
  #
  # @see #allow_user_suspend_actions?
  # @see #allow_user_delete_actions?
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
    build_action(actions, :no_action_user, bundle: bundle)

    user = try(:target_created_by)

    if user && allow_user_suspend_actions?(guardian, user)
      build_action(actions, :silence_user, bundle: bundle, client_action: "silence")
      build_action(actions, :suspend_user, bundle: bundle, client_action: "suspend")
    end

    if user && allow_user_delete_actions?(guardian, user)
      build_action(actions, :delete_user, bundle: bundle)
      build_action(actions, :delete_and_block_user, bundle: bundle)
    end

    bundle
  end

  # Check if the current guardian can perform user suspend actions. Used by
  # {#build_user_actions_bundle} to gate action availability. Callers to
  # {#build_user_actions_bundle} should override this method to implement custom logic.
  #
  # @param guardian [Guardian] Guardian instance to check permissions.
  # @param user [User] User instance to check permissions against.
  #
  # @return [Boolean] True if the guardian can suspend the user, false otherwise.
  def allow_user_suspend_actions?(guardian, user)
    guardian.can_suspend?(user)
  end

  # Check if the current guardian can perform user delete actions. Used by
  # {#build_user_actions_bundle} to gate action availability. Callers to
  # {#build_user_actions_bundle} should override this method to implement custom logic.
  #
  # @param guardian [Guardian] Guardian instance to check permissions.
  # @param user [User] User instance to check permissions against.
  #
  # @return [Boolean] True if the guardian can delete the user, false otherwise.
  def allow_user_delete_actions?(guardian, user)
    guardian.can_delete_user?(user)
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
    return unless pending?

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

  # Perform no action on the user. This action is a no-op and does not change the user's state.
  #
  # @param performed_by [User] The user performing the action.
  # @param args [Hash] Additional arguments for the action.
  #
  # @return [Reviewable::PerformResult] The result object.
  def perform_no_action_user(performed_by, args)
    successful_transition :approved
  end

  # Silence the user. This action is a no-op, as silencing a user is handled client-side.
  #
  # @param performed_by [User] The user performing the action.
  # @param args [Hash] Additional arguments for the action.
  #
  # @return [Reviewable::PerformResult] The result object.
  def perform_silence_user(performed_by, args)
    successful_transition :rejected
  end

  # Suspend the user. This action is a no-op, as suspending a user is handled client-side.
  #
  # @param performed_by [User] The user performing the action.
  # @param args [Hash] Additional arguments for the action.
  #
  # @return [Reviewable::PerformResult] The result object.
  def perform_suspend_user(performed_by, args)
    successful_transition :rejected
  end

  # Delete the user.
  #
  # @param performed_by [User] The user performing the action.
  # @param args [Hash] Additional arguments for the action.
  #
  # @return [Reviewable::PerformResult] The result object.
  def perform_delete_user(performed_by, args, &)
    user = try(:target_created_by)
    delete_user(user, delete_opts, performed_by)
    successful_transition :rejected, recalculate_score: false, &
  end

  # Delete and block the user.
  #
  # @param performed_by [User] The user performing the action.
  # @param args [Hash] Additional arguments for the action.
  #
  # @return [Reviewable::PerformResult] The result object.
  def perform_delete_and_block_user(performed_by, args, &)
    user = try(:target_created_by)
    delete_options = delete_opts
    delete_options.merge!(block_email: true, block_ip: true) if Rails.env.production?

    delete_user(user, delete_options, performed_by)
    successful_transition :rejected, recalculate_score: false, &
  end

  private

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

  # Delete the user and send an account deletion email.
  #
  # @param user [User] The user to delete.
  # @param delete_options [Hash] Options for deleting the user.
  # @param performed_by [User] The user performing the action.
  #
  # @return [void]
  def delete_user(user, delete_options, performed_by)
    email = user.email

    UserDestroyer.new(performed_by).destroy(user, delete_options)

    message = UserNotifications.account_deleted(email, self)
    Email::Sender.new(message, :account_deleted).send
  end

  # Create a successful transition result.
  #
  # @param to_state [Symbol] The state to transition to.
  # @param recalculate_score [Boolean] Whether to recalculate the score.
  # @yield [result] The result object.
  #
  # @return [Reviewable::PerformResult] The created result object.
  def successful_transition(to_state, recalculate_score: true)
    create_result(:success, to_state) do |result|
      result.recalculate_score = recalculate_score
      result.update_flag_stats = { status: to_state, user_ids: [created_by_id] } if FLAGGABLE
      yield result if block_given?
    end
  end

  # Create a result object.
  #
  # @param status [Symbol] The status of the result.
  # @param transition_to [Symbol] The state to transition to.
  # @yield [result] The result object.
  #
  # @return [Reviewable::PerformResult] The created result object.
  def create_result(status, transition_to = nil)
    result = Reviewable::PerformResult.new(self, status)
    result.transition_to = transition_to
    yield result if block_given?
    result
  end
end
