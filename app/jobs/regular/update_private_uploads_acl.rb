# frozen_string_literal: true

module Jobs
  class UpdatePrivateUploadsAcl < Jobs::Base

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
