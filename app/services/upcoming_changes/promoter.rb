# frozen_string_literal: true

class UpcomingChanges::Promoter
  include Service::Base

  params do
    attribute :setting
    attribute :promotion_status_threshold

    before_validation do
      self.setting = setting.to_sym
      self.promotion_status_threshold = promotion_status_threshold.to_sym
    end

    validates :setting, presence: true
    validates :promotion_status_threshold, presence: true
    validates :promotion_status_threshold, inclusion: { in: UpcomingChanges.statuses.keys }
  end

  policy :meets_promotion_criteria
  policy :setting_not_modified
  policy :setting_not_already_enabled
  step :process_upcoming_change

  private

  def meets_promotion_criteria(params:)
    UpcomingChanges.meets_or_exceeds_status?(params.setting, params.promotion_status_threshold)
  end

  def setting_not_modified(params:)
    # For permanent changes, we always force promotion no matter what
    # the admin has previously done.
    if UpcomingChanges.change_status_value(params.setting) == UpcomingChanges.statuses[:permanent]
      return true
    end

    !SiteSetting.exists?(name: params.setting)
  end

  def setting_not_already_enabled(params:)
    !SiteSetting.public_send(params.setting)
  end

  def process_upcoming_change(params:, guardian:)
    UpcomingChanges::Toggle.call(
      params: {
        setting_name: params.setting,
        enabled: true,
      },
      guardian:,
      options: {
        log_change: false,
      },
    )

    context =
      I18n.t(
        "staff_action_logs.upcoming_changes.log_promoted",
        change_status: UpcomingChanges.change_status(params.setting),
        promotion_status_threshold: params.promotion_status_threshold,
        base_path: Discourse.base_path,
      )

    StaffActionLogger.new(Discourse.system_user).log_upcoming_change_toggle(
      params.setting,
      false,
      true,
      { context: },
    )
  end
end
