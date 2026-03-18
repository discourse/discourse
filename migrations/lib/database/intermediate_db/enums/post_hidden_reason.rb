# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB::Enums
  module PostHiddenReason
    extend ::Migrations::Enum

    FLAG_THRESHOLD_REACHED = 1
    FLAG_THRESHOLD_REACHED_AGAIN = 2
    NEW_USER_SPAM_THRESHOLD_REACHED = 3
    FLAGGED_BY_TL3_USER = 4
    EMAIL_SPAM_HEADER_FOUND = 5
    FLAGGED_BY_TL4_USER = 6
    EMAIL_AUTHENTICATION_RESULT_HEADER = 7
    IMPORTED_AS_UNLISTED = 8
  end
end
