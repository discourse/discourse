# frozen_string_literal: true

# This file is auto-generated from the FilesDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module FilesDB
      module Enums
        module UploadResultStatus
          extend Migrations::Enum

          ERROR = "error"
          OK = "ok"
          SKIPPED = "skipped"
        end
      end
    end
  end
end
