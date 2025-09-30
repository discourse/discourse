# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB::Enums
  module SubcategoryListStyle
    extend ::Migrations::Enum

    BOXES = "boxes"
    BOXES_WITH_FEATURED_TOPICS = "boxes_with_featured_topics"
    ROWS = "rows"
    ROWS_WITH_FEATURED_TOPICS = "rows_with_featured_topics"
  end
end
