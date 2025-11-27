# frozen_string_literal: true

class UpcomingChanges::Toggle
  include Service::Base

  # For cases like the UpcomingChanges::Promoter where we don't want to log
  # the change again since it's already being logged there.
  options { attribute :log_change, default: true }

  params do
    attribute :setting_name, :string
    attribute :enabled, :boolean
    validates :setting_name, presence: true
    validates :enabled, inclusion: [true, false]
  end

  policy :current_user_is_admin, class_name: User::Policy::IsAdmin
  policy :setting_is_available, class_name: SiteSetting::Policy::SettingIsAvailable
  transaction { step :toggle }

  private

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def toggle(params:, guardian:, options:)
    # TODO (martin) Remove this once we release upcoming changes,
    # otherwise it will be confusing for people to see log messages
    # about upcoming changes via "What's new?" experimental toggles
    # before we update that UI.
    if SiteSetting.enable_upcoming_changes
      previous_value = SiteSetting.public_send(params.setting_name)
      SiteSetting.send("#{params.setting_name}=", params.enabled)

      if options.log_change
        StaffActionLogger.new(guardian.user).log_upcoming_change_toggle(
          params.setting_name,
          previous_value,
          params.enabled,
          { context: I18n.t("staff_action_logs.upcoming_changes.log_manually_toggled") },
        )
      end
    else
      if options.log_change
        SiteSetting.set_and_log(params.setting_name, params.enabled, guardian.user)
      else
        SiteSetting.public_send("#{params.setting_name}=", params.enabled)
      end
    end
  end
end
