# frozen_string_literal: true

module Live
  # Batch the same two group checks as Guardian#can_send_live_file? for rosters.
  # Never trust participant/heartbeat metadata to grant a sender permission.
  class FileTransferEntitlements
    def self.for_users(users)
      users = Array(users).select { |user| user.id > 0 }
      return Set.new unless SiteSetting.live_enabled? && users.present?

      Live::MediaEntitlements.user_ids_in_groups(users, SiteSetting.live_allowed_groups_map) &
        Live::MediaEntitlements.user_ids_in_groups(
          users,
          SiteSetting.live_file_transfer_allowed_groups_map,
        )
    end
  end
end
