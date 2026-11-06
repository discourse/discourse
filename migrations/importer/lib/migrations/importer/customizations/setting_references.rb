# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      # Site settings that hold theme or color scheme ids. Their setting type is
      # a plain integer, so they can't be recognized by type.
      module SettingReferences
        THEME_SETTINGS = %w[default_theme_id].freeze
        COLOR_SCHEME_SETTINGS = %w[default_dark_mode_color_scheme_id].freeze
      end
    end
  end
end
