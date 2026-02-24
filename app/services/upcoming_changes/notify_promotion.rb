# frozen_string_literal: true

# Notify admins of a specific upcoming change's promotion,
# which occurs when the change has reached the promotion status
# defined by SiteSetting.promote_upcoming_changes_on_status.
#
# Since the site setting is not actually changed in the database
# when an upcoming change is automatically promoted, we also
# fire off a DiscourseEvent that developers can listen to
# in 015-track-upcoming-change-toggle.rb.
#
# Admins will only be notified once for each upcoming change,
# both via a staff action log and a Notification in the UI.
# We don't need to notify admins if they have manually opted in
# or out of the change, since that overrides the automatic promotion.
class UpcomingChanges::NotifyPromotion
  include Service::Base

  params do
    attribute :setting_name, :symbol
    attribute :admin_user_ids, :array
    attribute :changes_already_notified_about_promotion, :array, default: []

    validates :setting_name, presence: true
    validates :admin_user_ids, presence: true
  end

  policy :setting_is_available
  policy :meets_or_exceeds_status
  policy :change_has_not_already_been_notified_about_promotion
  policy :admin_has_not_manually_toggled

  try do
    step :log_promotion
    model :records
    step :notify_admins
    step :create_event
    step :trigger_discourse_event
  end

  private

  def setting_is_available(params:)
    SiteSetting.respond_to?(params.setting_name)
  end

  def meets_or_exceeds_status(params:)
    UpcomingChanges.meets_or_exceeds_status?(
      params.setting_name,
      SiteSetting.promote_upcoming_changes_on_status.to_sym,
    )
  end

  def change_has_not_already_been_notified_about_promotion(params:)
    !params.changes_already_notified_about_promotion.include?(params.setting_name)
  end

  def admin_has_not_manually_toggled(params:)
    !SiteSetting.modified.key?(params.setting_name)
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

  def fetch_records(params:)
    data = {
      upcoming_change_name: params.setting_name,
      upcoming_change_humanized_name: SiteSetting.humanized_name(params.setting_name),
    }.to_json

    params.admin_user_ids.map do |admin_id|
      {
        user_id: admin_id,
        notification_type: Notification.types[:upcoming_change_automatically_promoted],
        data:,
      }
    end
  end

  def notify_admins(records:)
    Notification::Action::BulkCreate.call(records:)
  end

  def create_event(params:)
    UpcomingChangeEvent.create!(
      event_type: :admins_notified_automatic_promotion,
      upcoming_change_name: params.setting_name,
      acting_user: Discourse.system_user,
    )
  end

  def trigger_discourse_event(params:)
    DiscourseEvent.trigger(:upcoming_change_enabled, params.setting_name)
  end
end
