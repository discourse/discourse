# frozen_string_literal: true

class UpcomingChanges::Toggle
  include Service::Base

  params do
    attribute :setting_name, :string
    attribute :enabled, :boolean
    validates :setting_name, presence: true
    validates :enabled, inclusion: [true, false]
  end

  policy :current_user_is_admin
  policy :setting_is_available
  transaction { step :toggle }

  private

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def setting_is_available(params:)
    SiteSetting.respond_to?(params.setting_name)
  end

  def toggle(params:, guardian:)
    # TODO (martin) Remove this once we release upcoming changes,
    # otherwise it will be confusing for people to see log messages
    # about upcoming changes via "What's new?" experimental toggles
    # before we update that UI.
    if SiteSetting.enable_upcoming_changes
      previous_value = SiteSetting.public_send(params.setting_name)
      SiteSetting.send("#{params.setting_name}=", params.enabled)
      StaffActionLogger.new(guardian.user).log_upcoming_change_toggle(
        params.setting_name,
        previous_value,
        params.enabled,
        { context: I18n.t("staff_action_logs.upcoming_changes.log_manually_toggled") },
      )
    else
      SiteSetting.set_and_log(
        params.setting_name,
        !SiteSetting.public_send(params.setting_name),
        guardian.user,
      )
    end
  end
end
