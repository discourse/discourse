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
#
# Note that "has this promotion been handled?" and "have admins been notified?"
# are deliberately separate questions. The former is keyed on the
# automatically_promoted event and gates the whole service, since promoting twice
# would re-fire :upcoming_change_enabled every time the job runs. The latter is
# keyed on the admins_notified_automatic_promotion event and only skips the
# notification, so a change that was pre-marked as notified (see
# UpcomingChanges::Action::BackfillNotifiedEvents) still promotes for real.
class UpcomingChanges::NotifyPromotion
  include Service::Base

  params do
    attribute :setting_name, :symbol
    attribute :admin_user_ids, :array
    attribute :changes_already_notified_about_promotion, :array, default: []
    attribute :changes_already_promoted, :array, default: []

    validates :setting_name, presence: true
    validates :admin_user_ids, presence: true
  end

  policy :setting_is_available
  policy :change_should_be_displayed
  policy :meets_or_exceeds_status
  policy :promotion_not_already_handled
  policy :admin_has_not_manually_toggled
  policy :should_notify_admins

  try do
    transaction do
      step :log_promotion
      only_if(:notify_admins?) do
        model :existing_notifications, optional: true
        model :bulk_notification_new_records, optional: true
        step :notify_admins
        step :create_notified_event
      end
      step :create_automatically_promoted_event
    end

    step :trigger_discourse_event
  end

  private

  def setting_is_available(params:)
    SiteSetting.respond_to?(params.setting_name)
  end

  def change_should_be_displayed(params:)
    UpcomingChanges::ConditionalDisplay.should_display?(params.setting_name)
  end

  def meets_or_exceeds_status(params:)
    UpcomingChanges.meets_or_exceeds_status?(
      params.setting_name,
      SiteSetting.promote_upcoming_changes_on_status.to_sym,
    )
  end

  def promotion_not_already_handled(params:)
    !params.changes_already_promoted.include?(params.setting_name)
  end

  def admin_has_not_manually_toggled(params:)
    !SiteSetting.setting_modified_from_default?(params.setting_name)
  end

  def should_notify_admins(params:)
    UpcomingChanges.should_notify_admins?
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

  def notify_admins?(params:)
    !params.changes_already_notified_about_promotion.include?(params.setting_name)
  end

  def fetch_existing_notifications(params:)
    Notification.where(
      notification_type: Notification.types[:upcoming_change_automatically_promoted],
      user_id: params.admin_user_ids,
      read: false,
    )
  end

  def fetch_bulk_notification_new_records(params:, existing_notifications:)
    existing_by_user = existing_notifications.to_a.index_by(&:user_id)
    params.admin_user_ids.map do |admin_id|
      {
        user_id: admin_id,
        notification_type: Notification.types[:upcoming_change_automatically_promoted],
        data:
          UpcomingChanges::Action::NotificationDataMerger.call(
            existing_notification_data: existing_by_user[admin_id]&.data,
            new_change_name: params.setting_name,
          ).to_json,
      }
    end
  end

  def notify_admins(params:, bulk_notification_new_records:, existing_notifications:)
    merge_with_existing = existing_notifications.to_a.any?

    Notification.transaction do
      existing_notifications.delete_all if merge_with_existing
      Notification::Action::BulkCreate.call(
        records: bulk_notification_new_records,
        skip_send_email: merge_with_existing,
      )
    end
  end

  def create_notified_event(params:)
    UpcomingChangeEvent.create!(
      event_type: :admins_notified_automatic_promotion,
      upcoming_change_name: params.setting_name,
      acting_user: Discourse.system_user,
    )
  end

  def create_automatically_promoted_event(params:)
    UpcomingChangeEvent.find_or_create_by(
      event_type: :automatically_promoted,
      upcoming_change_name: params.setting_name,
    ) { |event| event.acting_user = Discourse.system_user }
  end

  def trigger_discourse_event(params:)
    DiscourseEvent.trigger(:upcoming_change_enabled, params.setting_name)
  end
end
