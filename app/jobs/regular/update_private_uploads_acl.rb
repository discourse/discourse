# frozen_string_literal: true

module Jobs
  class UpdatePrivateUploadsAcl < Jobs::Base
    # only runs when one of "SiteSetting.prevent_anons_from_downloading_files, SiteSetting.secure_images" is updated
    def execute(args)
      return if !SiteSetting.enable_s3_uploads

      type = "attachment"

      type = "image" if args[:name] && args[:name] == "secure_images"

      Upload.find_each do |upload|
        Discourse.store.update_upload_ACL(upload, type: type)
      end
    end

  end
end
