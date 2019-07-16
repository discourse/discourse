# frozen_string_literal: true

module Jobs
  class UpdatePrivateUploadsAcl < Jobs::Base
    # only runs when one of "SiteSetting.prevent_anons_from_downloading_files, SiteSetting.secure_images" is updated
    def execute(args)
      return if !SiteSetting.enable_s3_uploads

      type = "attachment"

      type = "image" if args[:name] && args[:name] == "secure_images"

      Upload.find_each do |upload|
        next if upload.for_theme || upload.for_site_setting

        is_image = FileHelper.is_supported_image?(upload.original_filename)

        if type == "attachment" && !is_image
          upload.secure = SiteSetting.prevent_anons_from_downloading_files?
          upload.save
          Discourse.store.update_upload_ACL(upload, type: type)
        end

        if type == "image" && is_image
          upload.secure = SiteSetting.secure_images?
          upload.save
          Discourse.store.update_upload_ACL(upload, type: type)
        end
      end
    end

  end
end
