# frozen_string_literal: true

# This file is auto-generated from the FilesDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module FilesDB
      module Enums
        module UploadSkipReason
          extend Migrations::Enum

          DOWNLOAD_ERROR = "download_error"
          ERROR = "error"
          FILE_NOT_FOUND = "file_not_found"
          TOO_MANY_RETRIES = "too_many_retries"
          UPLOAD_SIZE_EXCEEDED = "upload_size_exceeded"
        end
      end
    end
  end
end
