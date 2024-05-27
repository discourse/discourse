# frozen_string_literal: true

##
# There are certain conditions with secure uploads when the security of
# uploads will need to change depending on the context they reside in.
#
# For example on these conditions:
#  * Topic category change
#  * Topic switching between PM and public topic
#  * Post moving between topics
#
# We need to go through all of the posts in that topic that
# own uploads via access_control_post_id, then for those uploads determine
# if they still need to be secure or not. For example an upload could be
# secure if it is in a PM, and then when the topic gets converted to a public
# topic the upload no longer needs to remain secure as it is no longer in
# a secure context.
class TopicUploadSecurityManager
  def initialize(topic)
    @topic = topic
  end

  def run
    rebaked_posts = []
    Rails.logger.debug("Updating upload security in topic #{@topic.id}")
    posts_owning_uploads.each do |post|
      Post.transaction do
        Rails.logger.debug("Updating upload security in topic #{@topic.id} - post #{post.id}")
        post.topic = @topic

        secure_status_did_change =
          post.owned_uploads_via_access_control.any? do |upload|
            # We already have the post preloaded so we may as well
            # attach it here to avoid another load in UploadSecurity
            # (which is called via update_secure_status)
            upload.access_control_post = post
            upload.update_secure_status(source: "topic upload security")
          end

        if secure_status_did_change
          post.rebake!
          rebaked_posts << post
        end
        Rails.logger.debug(
          "Security updated & rebake complete in topic #{@topic.id} - post #{post.id}",
        )
      end
    end

    return rebaked_posts if !SiteSetting.secure_uploads

    # We only want to do this if secure uploads is enabled. If
    # the setting is turned on after a site has been running
    # already, we want to make sure that any post moves after
    # this are handled and upload secure statuses and ACLs
    # are updated appropriately, as well as setting the access control
    # post for secure uploads missing it.
    #
    # Examples (all after secure uploads is enabled):
    #
    #  -> a public topic is moved to a private category after
    #  -> a PM is converted to a public topic
    #  -> a public topic is converted to a PM
    #  -> a topic is moved from a private to a public category
    posts_with_unowned_uploads.each do |post|
      Post.transaction do
        Rails.logger.debug(
          "Setting upload access control posts in topic #{@topic.id} - post #{post.id}",
        )
        post.topic = @topic

        secure_status_did_change =
          post.uploads.any? do |upload|
            first_post_upload_appeared_in =
              upload.upload_references.where(target_type: "Post").first.target
            if first_post_upload_appeared_in == post
              upload.update(access_control_post: post)
              upload.update_secure_status(source: "topic upload security")
            else
              false
            end
          end

        if secure_status_did_change
          post.rebake!
          rebaked_posts << post
        end
        Rails.logger.debug(
          "Completed changing access control posts #{secure_status_did_change ? "and rebaking" : ""} in topic #{@topic.id} - post #{post.id}",
        )
      end
    end

    Rails.logger.debug("Completed updating upload security in topic #{@topic.id}!")
    rebaked_posts
  end

  private

  def posts_owning_uploads
    Post.where(topic_id: @topic.id, id: Upload.select(:access_control_post_id))
  end

  def posts_with_unowned_uploads
    Post.where(
      topic_id: @topic.id,
      id:
        UploadReference.where(
          target_type: "Post",
          upload: Upload.where(access_control_post_id: nil),
        ).select(:target_id),
    ).includes(:uploads)
  end
end
