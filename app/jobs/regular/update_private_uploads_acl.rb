# frozen_string_literal: true

module Jobs
  class UpdatePrivateUploadsAcl < ::Jobs::Base
    # only runs when SiteSetting.prevent_anons_from_downloading_files is updated
    def execute(args)
      return if !SiteSetting.Upload.enable_s3_uploads

      Upload.find_each do |upload|
        if !FileHelper.is_supported_media?(upload.original_filename)
          upload.update_secure_status
        end
      end
    end

  end
end
