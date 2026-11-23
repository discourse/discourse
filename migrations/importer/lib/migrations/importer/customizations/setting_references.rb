# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      # Site settings that hold theme ids. Their setting type is a plain
      # integer, so they can't be recognized by type.
      module SettingReferences
        THEME_SETTINGS = %w[default_theme_id].freeze
      end
    end
  end
end
