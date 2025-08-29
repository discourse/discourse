# frozen_string_literal: true

module Migrations::Database::IntermediateDB::Enums
  module SiteSettingAction
    extend Migrations::Enum

    UPDATE = 1
    MERGE = 2
  end
end
