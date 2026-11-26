# frozen_string_literal: true

module BulkImport::DiscourseMerge
  module MappingActions
    CATEGORIES = {
      "Keep category" => "copy",
      "Move discussions only" => "topics_only",
      "Use existing category" => "reuse",
      "Exclude" => "exclude",
    }.freeze
    TOPICS = {
      "Use category rule" => "inherit",
      "Move discussion" => "include",
      "Exclude" => "exclude",
    }.freeze
    GROUPS = {
      "Match identical group" => "auto",
      "Keep separate" => "copy",
      "Rename" => "copy",
      "Merge into existing group" => "reuse",
      "Exclude group" => "exclude",
    }.freeze
    STAFF_ROLES = {
      "Keep source staff roles" => "preserve",
      "Import staff as regular users" => "regular_users",
    }.freeze
  end
end
