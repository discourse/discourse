module Jobs
  class FixInvalidGravatarUploads < Jobs::Onceoff
    def execute_onceoff(args)
      Upload.where(original_filename: "gravatar.png").find_each do |upload|
        extension = FastImage.type(Discourse.store.path_for(upload))
        current_extension = upload.extension

        if extension.to_s.downcase != current_extension.to_s.downcase
          upload.user.user_avatar.update_gravatar!
        end
      end
    end
  end
end
