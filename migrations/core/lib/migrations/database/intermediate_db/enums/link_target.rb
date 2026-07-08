# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module Enums
        module LinkTarget
          extend Migrations::Enum

          TOPIC = 1
          POST = 2
          USER = 3
          CATEGORY = 4
          TAG = 5
          GROUP = 6
          BADGE = 7
        end
      end
    end
  end
end
