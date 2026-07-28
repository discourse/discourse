# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/tooling/config/schema/" and then run
# `migrations/bin/disco schema generate` to regenerate this file.

module Migrations
  module Database
    module IntermediateDB
      module Enums
        module MentionType
          extend Migrations::Enum

          USER = 1
          GROUP = 2
          HERE = 3
          ALL = 4
        end
      end
    end
  end
end
