# frozen_string_literal: true

module Jobs
  class CleanupAclsForDeleted < ::Jobs::Base
    def execute(args)
      group_id = args[:group_id]

      # TODO (martin) Handle users in a followup PR
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

      AccessControlList
        .where("allowed_group_ids = '{}'::bigint[]")
        .where("allowed_user_ids = '{}'::bigint[]")
        .delete_all
    end
  end
end
