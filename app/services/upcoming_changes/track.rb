# frozen_string_literal: true

# Handles tracking the addition, removal, and status changes of upcoming changes,
# via UpcomingChangeEvent records, and subsequently notifying admins that the
# upcoming change is available for them to opt-in to, based on certain criteria
# that are explained in the Action classes.
#
# Called from the Jobs::Scheduled::CheckUpcomingChanges job.
class UpcomingChanges::Track
  include Service::Base

  model :all_admins
  model :added_changes, optional: true
  model :removed_changes, optional: true
  model :status_changes, optional: true

  private

  def fetch_all_admins
    User.human_users.admins
  end

  def fetch_added_changes(all_admins:)
    result = UpcomingChanges::Action::TrackAddedChanges.call(all_admins:)
    context[:notified_admins_for_added_changes] = result[:notified_changes]
    result[:added_changes]
  end

  def fetch_removed_changes
    UpcomingChanges::Action::TrackRemovedChanges.call
  end

  def fetch_status_changes(added_changes:, removed_changes:, all_admins:)
    result =
      UpcomingChanges::Action::TrackStatusChanges.call(
        all_admins:,
        added_changes:,
        removed_changes:,
      )
    context[:notified_admins_for_added_changes] += result[:notified_changes]
    result[:status_changes]
  end
end
