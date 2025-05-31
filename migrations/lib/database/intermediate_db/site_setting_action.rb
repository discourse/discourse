# frozen_string_literal: true

module Migrations::Database::IntermediateDB
  module SiteSettingAction
    extend ::Migrations::Enum

    define_values :update, :append
  end
end
