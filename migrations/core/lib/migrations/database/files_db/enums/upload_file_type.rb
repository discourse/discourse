# frozen_string_literal: true

# This file is auto-generated from the FilesDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module FilesDB
      module Enums
        module UploadFileType
          extend Migrations::Enum

          IMAGE = 0
          AUDIO = 1
          VIDEO = 2
          ATTACHMENT = 3
        end
      end
    end
  end
end
