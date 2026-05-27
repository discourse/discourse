# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module Enums
        module SiteSettingImportMode
          extend Migrations::Enum

          AUTO = 0
          OVERRIDE = 1
          APPEND = 2
        end
      end
    end
  end
end
