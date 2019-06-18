# frozen_string_literal: true

module Jobs
  class UpdatePrivateUploadsAcl < Jobs::Base
    # only runs when SiteSetting.prevent_anons_from_downloading_files is updated
    def execute(args)
      return if !SiteSetting.enable_s3_uploads

      Upload.find_each do |upload|
        if !FileHelper.is_supported_image?(upload.original_filename)
          Discourse.store.update_upload_ACL(upload)
        end
      end
    end

  end
end
