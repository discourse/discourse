# frozen_string_literal: true

module Jobs
  class BackfillCategoryUploadSecurity < ::Jobs::Onceoff
    def execute_onceoff(_args)
      return if !SiteSetting.secure_uploads? || SiteSetting.secure_uploads_pm_only?

      topics_with_insecure_uploads.find_each do |topic|
        Jobs.enqueue(:update_topic_upload_security, topic_id: topic.id)
      end
    end

    private

    def topics_with_insecure_uploads
      insecure_uploads = Upload.where(secure: false)
      owned_topic_ids =
        Post
          .with_deleted
          .where(id: insecure_uploads.select(:access_control_post_id))
          .select(:topic_id)
      unowned_post_ids =
        UploadReference.where(
          target_type: "Post",
          upload: insecure_uploads.where(access_control_post_id: nil),
        ).select(:target_id)
      unowned_topic_ids = Post.with_deleted.where(id: unowned_post_ids).select(:topic_id)
      private_topics =
        Topic.with_deleted.joins(:category).where(categories: { read_restricted: true })

      private_topics.where(id: owned_topic_ids).or(private_topics.where(id: unowned_topic_ids))
    end
  end
end
