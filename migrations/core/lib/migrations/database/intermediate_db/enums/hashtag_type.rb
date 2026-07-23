# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module Enums
        module HashtagType
          extend Migrations::Enum

          CATEGORY = 1
          TAG = 2
        end
      end
    end
  end
end
