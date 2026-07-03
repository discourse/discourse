# frozen_string_literal: true
# script/fix_kanban_acl_permission_overlap.rb

TARGET_TYPE = "DiscourseKanban::Board"
PERMISSION_ORDER = %w[view edit manage] # low -> high

# nil fixes all overlapping groups. To fix only TL0:
# GROUP_IDS = [Group::AUTO_GROUPS[:trust_level_0]]
GROUP_IDS = nil

# DRY_RUN = ENV["DRY_RUN"] != "0"
dry_run = true

changed_rows = 0
deleted_rows = 0
removed_grants = 0
remaining_acls_by_target = {}

AccessControlList.transaction do
  AccessControlList
    .where(target_type: TARGET_TYPE, permission: PERMISSION_ORDER)
    .select(:id, :target_id, :permission, :allowed_group_ids, :allowed_user_ids)
    .group_by(&:target_id)
    .each do |target_id, acls|
      by_permission = acls.index_by(&:permission)
      remaining_acls_by_target[target_id] = by_permission.transform_values do |acl|
        { allowed_group_ids: acl.allowed_group_ids.dup, allowed_user_ids: acl.allowed_user_ids.dup }
      end

      PERMISSION_ORDER.each_with_index do |permission, index|
        acl = by_permission[permission]
        next if acl.blank?

        higher_permissions = PERMISSION_ORDER[(index + 1)..]
        next if higher_permissions.blank?

        higher_group_ids =
          higher_permissions
            .flat_map { |higher| by_permission[higher]&.allowed_group_ids || [] }
            .uniq

        remove_group_ids = acl.allowed_group_ids & higher_group_ids
        remove_group_ids &= GROUP_IDS if GROUP_IDS.present?
        next if remove_group_ids.blank?

        new_allowed_group_ids = acl.allowed_group_ids - remove_group_ids

        puts(
          "target_id=#{target_id} acl_id=#{acl.id} permission=#{permission} " \
            "removing_group_ids=#{remove_group_ids.inspect} " \
            "remaining_group_ids=#{new_allowed_group_ids.inspect}",
        )

        removed_grants += remove_group_ids.length

        if new_allowed_group_ids.empty? && acl.allowed_user_ids.empty?
          deleted_rows += 1
          remaining_acls_by_target[target_id].delete(permission)
          acl.destroy! unless dry_run
        else
          changed_rows += 1
          remaining_acls_by_target[target_id][permission][
            :allowed_group_ids
          ] = new_allowed_group_ids
          unless dry_run
            acl.update_columns(allowed_group_ids: new_allowed_group_ids, updated_at: Time.zone.now)
          end
        end
      end
    end

  raise ActiveRecord::Rollback if dry_run
end

puts "#{dry_run ? "Dry run" : "Done"}: removed_grants=#{removed_grants}, changed_rows=#{changed_rows}, deleted_rows=#{deleted_rows}"

puts "\nRemaining ACL permissions by target:"
remaining_acls_by_target.sort.each do |target_id, permissions|
  puts "target_id=#{target_id}"

  PERMISSION_ORDER.each do |permission|
    remaining_acl = permissions[permission]
    next if remaining_acl.blank?

    puts(
      "  #{permission}: " \
        "allowed_group_ids=#{remaining_acl[:allowed_group_ids].inspect} " \
        "allowed_user_ids=#{remaining_acl[:allowed_user_ids].inspect}",
    )
  end
end
