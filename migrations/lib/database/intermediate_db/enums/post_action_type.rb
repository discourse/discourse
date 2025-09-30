# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB::Enums
  module PostActionType
    extend ::Migrations::Enum

    LIKE = 2
    OFF_TOPIC = 3
    INAPPROPRIATE = 4
    NOTIFY_USER = 6
    NOTIFY_MODERATORS = 7
    SPAM = 8
    ILLEGAL = 10
  end
end
