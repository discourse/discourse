# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB::Enums
  module SiteSettingImportMode
    extend ::Migrations::Enum

    AUTO = 0
    OVERRIDE = 1
    APPEND = 2
  end
end
