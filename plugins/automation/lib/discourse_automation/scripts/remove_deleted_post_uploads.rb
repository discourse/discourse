# frozen_string_literal: true

# This script runs a revision to remove uploads that are attached to posts that have been deleted.
# This automation is intended to be used with clean_up_uploads job.

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scripts::REMOVE_DELETED_POST_UPLOADS) do
  version 1

  triggerables %i[recurring point_in_time]

  script do |trigger, fields|
    uploads_deleted_at = Time.now
    edit_reason = I18n.t("discourse_automation.scriptables.remove_deleted_post_uploads.edit_reason")

    # it matches both ![alt|size](upload://key) and [small.pdf|attachment](upload://key.pdf) (Number Bytes)
    upload_and_attachment_regex =
      %r{!?\[([^\]|]+)(?:\|[^\]]*)?\]\(upload://([A-Za-z0-9_-]+)[^)]*\)(?:\s*\([^)]*\))?}

    Post
      .with_deleted
      .where.not(deleted_at: nil)
      .joins(:upload_references)
      .where("upload_references.target_type = 'Post'")
      .each do |post|
        if updated_raw = post.raw.gsub!(upload_and_attachment_regex, "")
          if ok =
               post.revise(
                 Discourse.system_user,
                 { raw: updated_raw, edit_reason: edit_reason },
                 force_new_version: true,
                 skip_validations: true,
               )
            post.custom_fields["uploads_deleted_at"] = uploads_deleted_at
            post.save_custom_fields
          end
        end
      end
  end
end
