# frozen_string_literal: true

class ThemeTranslationSerializer < ApplicationSerializer
  root 'theme_translation'

  attributes :key, :value, :default
end
