# frozen_string_literal: true

module Live
  # Batch the same two group checks as Guardian#can_send_live_file? for rosters.
  # Never trust participant/heartbeat metadata to grant a sender permission.
  class FileTransferEntitlements
    def self.for_users(users)
      users = Array(users).select { |user| user.id > 0 }
      return Set.new unless SiteSetting.live_enabled? && users.present?

      ids_in_groups(users, SiteSetting.live_allowed_groups_map) &
        ids_in_groups(users, SiteSetting.live_file_transfer_allowed_groups_map)
    end

    def self.ids_in_groups(users, group_ids)
      return Set.new if group_ids.blank?

      pseudo_groups =
        group_ids & [Group::AUTO_GROUPS[:everyone], Group::AUTO_GROUPS[:logged_in_users]]
      if pseudo_groups.present? && users.first.in_any_groups?(pseudo_groups)
        return users.map(&:id).to_set
      end

      GroupUser.where(group_id: group_ids, user_id: users.map(&:id)).pluck(:user_id).to_set
    end
    private_class_method :ids_in_groups
  end
end
