module Jobs
  class FixInvalidGravatarUploads < Jobs::Onceoff
    def execute_onceoff(args)
      Upload.where(original_filename: "gravatar.png").find_each do |upload|
        # note, this still feels pretty expensive for a once off
        # we may need to re-evaluate this
        extension = FastImage.type(Discourse.store.path_for(upload))
        current_extension = upload.extension

        if extension.to_s.downcase != current_extension.to_s.downcase
          upload&.user&.user_avatar&.update_columns(last_gravatar_download_attempt: nil)
        end
      end
    end
  end
end
