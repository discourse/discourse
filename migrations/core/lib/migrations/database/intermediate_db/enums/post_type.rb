# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module Enums
        module PostType
          extend Migrations::Enum

          REGULAR = 1
          MODERATOR_ACTION = 2
          SMALL_ACTION = 3
          WHISPER = 4
        end
      end
    end
  end
end
