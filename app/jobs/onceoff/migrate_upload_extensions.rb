# frozen_string_literal: true

module Jobs

  class MigrateUploadExtensions < ::Jobs::Onceoff
    def execute_onceoff(args)
      Upload.find_each do |upload|
        upload.extension = File.extname(upload.original_filename)[1..10]
        upload.save
      end
    end
  end
end
