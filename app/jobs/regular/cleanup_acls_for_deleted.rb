# frozen_string_literal: true

module Jobs
  class CleanupAclsForDeleted < ::Jobs::Base
    def execute(args)
      group_id = args[:group_id]
      user_id = args[:user_id]
      return if group_id.blank? && user_id.blank?

      if group_id.present?
        AccessControlList.where("allowed_group_ids @> ARRAY[?]::bigint[]", group_id).update_all(
          [
            "allowed_group_ids = array_remove(allowed_group_ids, ?), updated_at = ?",
            group_id,
            Time.zone.now,
          ],
        )
      end

      if user_id.present?
        AccessControlList.where("allowed_user_ids @> ARRAY[?]::bigint[]", user_id).update_all(
          [
            "allowed_user_ids = array_remove(allowed_user_ids, ?), updated_at = ?",
            user_id,
            Time.zone.now,
          ],
        )
      end

      # Delete all ACLs that have no grantees left
      AccessControlList.where(
        "allowed_group_ids = '{}'::bigint[] AND allowed_user_ids = '{}'::bigint[]",
      ).delete_all
    end
  end
end
