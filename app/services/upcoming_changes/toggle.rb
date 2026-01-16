# frozen_string_literal: true

class UpcomingChanges::Toggle
  include Service::Base

  # For cases like the UpcomingChanges::Promote where we don't want to log
  # the change again since it's already being logged there.
  options { attribute :log_change, default: true }

  params do
    attribute :setting_name, :string
    attribute :enabled, :boolean
    validates :setting_name, presence: true
    validates :enabled, inclusion: [true, false]
  end

  policy :current_user_is_admin
  policy :setting_is_available
  transaction { step :toggle }

  only_if(:should_log_change) do
    step :log_change
    step :log_event
  end

  private

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def setting_is_available(params:)
    SiteSetting.respond_to?(params.setting_name)
  end

  def toggle(params:, guardian:, options:)
    # TODO (martin) Remove this once we release upcoming changes,
    # otherwise it will be confusing for people to see log messages
    # about upcoming changes via "What's new?" experimental toggles
    # before we update that UI.
    if SiteSetting.enable_upcoming_changes
      context[:previous_value] = SiteSetting.public_send(params.setting_name)
      SiteSetting.send("#{params.setting_name}=", params.enabled)
    else
      SiteSetting.public_send("#{params.setting_name}=", params.enabled)
    end
  end

  def should_log_change(options:)
    options.log_change
  end

  def log_change(params:, guardian:, options:)
    if SiteSetting.enable_upcoming_changes
      StaffActionLogger.new(guardian.user).log_upcoming_change_toggle(
        params.setting_name,
        context[:previous_value],
        params.enabled,
        { context: I18n.t("staff_action_logs.upcoming_changes.log_manually_toggled") },
      )
    else
      SiteSetting.log(params.setting_name, params.enabled, context[:previous_value], guardian.user)
    end
  end

  def log_event(params:, guardian:, options:)
    return unless SiteSetting.enable_upcoming_changes

    UpcomingChangeEvent.create!(
      event_type: params.enabled ? :manual_opt_in : :manual_opt_out,
      upcoming_change_name: params.setting_name,
      acting_user: guardian.user,
    )
  end
end
