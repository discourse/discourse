# frozen_string_literal: true

module Jobs
  class RebakeGifImages < ::Jobs::Onceoff
    def execute_onceoff(args)
      Upload.where("original_filename LIKE '%.gif'").find_each do |upload|
        uri = Discourse.store.path_for(upload) || upload.url
        upload.update!(animated: FastImage.animated?(uri))
      end

      User
        .joins(:uploaded_avatar)
        .where("uploads.original_filename LIKE '%.gif'")
        .where("uploads.animated")
        .find_each do |user|

        if path = Discourse.store.path_for(user.uploaded_avatar)
          file = File.new(path)
        else
          file = Discourse.store.download(user.uploaded_avatar)
        end

        # We want to reupload the avatar, but we also want to keep the
        # avatar until the new one is ready, so we will have to keep it
        # under a different hash (like we do for secure media).
        user.uploaded_avatar.update!(sha1: SecureRandom.hex(20))

        upload = UploadCreator.new(file, user.uploaded_avatar.original_filename, type: "avatar").create_for(user.id)
        user.update!(uploaded_avatar: upload)
      end

      # Destroy all optimized image for animated GIFs and let the system
      # recreate them on demand.
      OptimizedImage
        .joins(:upload)
        .where(uploads: { animated: true })
        .destroy_all

      nil
    end
  end
end
