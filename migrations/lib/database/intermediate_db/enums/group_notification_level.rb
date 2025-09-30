# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB::Enums
  module GroupNotificationLevel
    extend ::Migrations::Enum

    MUTED = 0
    REGULAR = 1
    NORMAL = 1
    TRACKING = 2
    WATCHING = 3
    WATCHING_FIRST_POST = 4
  end
end
