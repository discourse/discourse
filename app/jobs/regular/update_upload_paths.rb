# frozen_string_literal: true

module Jobs
  class UpdateUploadPaths < Jobs::Base

    def execute(args)
      private_uploads = SiteSetting.prevent_anons_from_downloading_files
      db = RailsMultisite::ConnectionManagement.current_db

      match_uploads = private_uploads ? "\/original\/" : "\/private\/"

      Upload.where("url ~ '#{match_uploads}'").find_each do |upload|
        if !FileHelper.is_supported_image?(upload.original_filename)
          upload.make_private if private_uploads
          upload.make_public if !private_uploads
        end
      end

      Post.where("cooked LIKE ?", "%href%").find_each(&:rebake!)

    end
  end
end
