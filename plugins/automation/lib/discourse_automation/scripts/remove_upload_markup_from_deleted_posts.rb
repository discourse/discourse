# frozen_string_literal: true

# This script runs a revision to remove upload and attachment markup that are attached to posts that have been deleted.
# This automation is intended to be used with clean_up_uploads job.
# On the next clean_up_uploads job, uploads that are no longer referenced in any post will be deleted from the system.

DiscourseAutomation::Scriptable.add(
  DiscourseAutomation::Scripts::REMOVE_UPLOAD_MARKUP_FROM_DELETED_POSTS,
) do
  version 1

  triggerables %i[recurring point_in_time]

  script do |trigger, fields|
    uploads_removed_at = Time.now
    edit_reason =
      I18n.t("discourse_automation.scriptables.remove_upload_markup_from_deleted_posts.edit_reason")

    # it matches both ![alt|size](upload://key) and [small.pdf|attachment](upload://key.pdf) (Number Bytes)
    upload_and_attachment_regex =
      %r{!?\[([^\]|]+)(?:\|[^\]]*)?\]\(upload://([A-Za-z0-9_-]+)[^)]*\)(?:\s*\([^)]*\))?}

    Post
      .with_deleted
      .where.not(deleted_at: nil)
      .joins(:upload_references)
      .where("upload_references.target_type = 'Post'")
      .joins(
        "LEFT JOIN post_custom_fields ON posts.id = post_custom_fields.post_id AND post_custom_fields.name = 'uploads_removed_at'",
      )
      .where("post_custom_fields.post_id IS NULL")
      .distinct
      .limit(1000)
      .each do |post|
        if updated_raw = post.raw.gsub!(upload_and_attachment_regex, "")
          if ok =
               post.revise(
                 Discourse.system_user,
                 { raw: updated_raw, edit_reason: edit_reason },
                 force_new_version: true,
                 skip_validations: true,
               )
            post.custom_fields["uploads_removed_at"] = uploads_removed_at
            post.save_custom_fields
          end
        end
      end
  end
end
