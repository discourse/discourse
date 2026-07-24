# frozen_string_literal: true

module DiscoursePostEvent
  # Resolves an event's image into an Upload, returning a secure upload only when the post author may use it.
  class Event::Action::ResolveImageUpload < Service::ActionBase
    option :image
    option :post

    def call
      return if image.blank?

      upload = find_upload
      return if upload.nil?

      upload if usable_by_author?(upload)
    end

    private

    def find_upload
      if image.start_with?("upload://")
        sha1 = Upload.sha1_from_short_url(image)
        Upload.find_by(sha1: sha1) if sha1
      else
        Upload.get_from_url(image)
      end
    end

    def usable_by_author?(upload)
      !upload.secure? || upload.user_id == post.user_id ||
        UserUpload.exists?(upload_id: upload.id, user_id: post.user_id)
    end
  end
end
