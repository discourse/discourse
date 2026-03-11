# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB::Enums
  module LogEntryType
    extend ::Migrations::Enum

    ERROR = "error"
    INFO = "info"
    WARNING = "warning"
  end
end
