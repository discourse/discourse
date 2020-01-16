# frozen_string_literal: true

class TopicUploadSecurityManager
  def initialize(topic)
    @topic = topic
  end

  def run
    posts_owning_uploads.each do |post|
      post.topic = @topic

      secure_status_did_change = post.owned_uploads_via_access_control.any? do |upload|
        # we have already got the post preloaded so we may as well
        # attach it here to avoid another load in UploadSecurity
        upload.access_control_post = post
        upload.update_secure_status
      end
      post.rebake! if secure_status_did_change
    end

    return if !SiteSetting.secure_media

    # we only want to do this if secure media is enabled. if
    # the setting is turned on after a site has been running
    # already, we want to make sure that any post moves after
    # this are handled and upload secure statuses and ACLs
    # are updated appropriately, as well as setting the access control
    # post for secure uploads missing it.
    #
    # examples (all after secure media is enabled):
    #
    #  -> a public topic is moved to a private category after
    #  -> a PM is converted to a public topic
    #  -> a public topic is converted to a PM
    #  -> a topic is moved from a private to a public category
    posts_with_unowned_uploads.each do |post|
      post.topic = @topic

      secure_status_did_change = post.uploads.any? do |upload|
        first_post_upload_appeared_in = upload.post_uploads.first.post
        if first_post_upload_appeared_in == post
          upload.update(access_control_post: post)
          upload.update_secure_status
        else
          false
        end
      end

      post.rebake! if secure_status_did_change
    end
  end

  private

  def posts_owning_uploads
    Post.where(
      topic_id: @topic.id
    ).joins('INNER JOIN uploads ON access_control_post_id = posts.id')
  end

  def posts_with_unowned_uploads
    Post
      .where(topic_id: @topic.id)
      .joins('INNER JOIN post_uploads ON post_uploads.post_id = posts.id')
      .joins('INNER JOIN uploads ON post_uploads.upload_id = uploads.id')
      .where('uploads.access_control_post_id IS NULL')
      .includes(:uploads)
  end
end
