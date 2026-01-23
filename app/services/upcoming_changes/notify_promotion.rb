# frozen_string_literal: true

# Notify admins of a specific upcoming change's promotion,
# which occurs when the change has reached the promotion status
# defined by SiteSetting.promote_upcoming_changes_on_status.
#
# The actual checks to determine whether to call this notifier
# occur in Jobs::Scheduled::CheckUpcomingChanges.
class UpcomingChanges::NotifyPromotion
  include Service::Base

  params do
    attribute :setting_name, :symbol
    validates :setting_name, presence: true
  end

  policy :setting_is_available
  step :log_promotion
  step :notify_admins
  step :create_event

  private

  def setting_is_available(params:)
    SiteSetting.respond_to?(params.setting_name)
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

  def notify_admins(params:)
    data = {
      upcoming_change_name: params.setting_name,
      upcoming_change_humanized_name: SiteSetting.humanized_name(params.setting_name),
    }.to_json

    records =
      User
        .human_users
        .admins
        .pluck(:id)
        .map do |admin_id|
          {
            user_id: admin_id,
            notification_type: Notification.types[:upcoming_change_automatically_promoted],
            data:,
          }
        end

    Notification::Action::BulkCreate.call(records:)
  end

  def create_event(params:)
    UpcomingChangeEvent.create!(
      event_type: :admins_notified_automatic_promotion,
      upcoming_change_name: params.setting_name,
      acting_user: Discourse.system_user,
    )
  end
end
