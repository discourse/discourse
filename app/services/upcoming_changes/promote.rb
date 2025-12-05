# frozen_string_literal: true

class UpcomingChanges::Promote
  include Service::Base

  params do
    attribute :setting_name
    attribute :promotion_status_threshold

    before_validation do
      self.setting_name = setting_name.try(:to_sym)
      self.promotion_status_threshold = promotion_status_threshold.try(:to_sym)
    end

    validates :setting_name, presence: true
    validates :promotion_status_threshold,
              presence: true,
              inclusion: {
                in: UpcomingChanges.statuses.keys,
              }
  end

  policy :current_user_is_admin
  policy :setting_is_available, class_name: SiteSetting::Policy::SettingIsAvailable
  policy :meets_promotion_criteria
  policy :setting_not_modified
  policy :setting_not_already_enabled
  step :toggle_upcoming_change
  step :log_promotion

  private

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def meets_promotion_criteria(params:)
    UpcomingChanges.meets_or_exceeds_status?(params.setting_name, params.promotion_status_threshold)
  end

  def setting_not_modified(params:)
    # For permanent changes, we always force promotion no matter what
    # the admin has previously done.
    if UpcomingChanges.change_status_value(params.setting_name) ==
         UpcomingChanges.statuses[:permanent]
      return true
    end

    !SiteSetting.exists?(name: params.setting_name)
  end

  def setting_not_already_enabled(params:)
    !SiteSetting.public_send(params.setting_name)
  end

  def toggle_upcoming_change(params:, guardian:)
    UpcomingChanges::Toggle.call(
      params: {
        setting_name: params.setting_name,
        enabled: true,
      },
      guardian:,
      options: {
        log_change: false,
      },
    ) do |result|
      on_failure do
        fail!("Unexpected failure when enabling upcoming change #{params.setting_name}")
      end
    end
  end

  def log_promotion(params:, guardian:)
    context =
      I18n.t(
        "staff_action_logs.upcoming_changes.log_promoted",
        change_status: UpcomingChanges.change_status(params.setting_name).to_s.titleize,
        base_path: Discourse.base_path,
      )

    StaffActionLogger.new(Discourse.system_user).log_upcoming_change_toggle(
      params.setting_name,
      false,
      true,
      { context: },
    )
  end
end
