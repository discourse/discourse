# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module Enums
        module UploadType
          extend Migrations::Enum

          AVATAR = 0
          CARD_BACKGROUND = 1
          CUSTOM_EMOJI = 2
          PROFILE_BACKGROUND = 3
        end
      end
    end
  end
end
