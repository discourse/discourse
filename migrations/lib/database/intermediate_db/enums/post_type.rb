# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB::Enums
  module PostType
    extend ::Migrations::Enum

    REGULAR = 1
    MODERATOR_ACTION = 2
    SMALL_ACTION = 3
    WHISPER = 4
  end
end
