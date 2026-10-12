# frozen_string_literal: true
class AddOriginalTranslationToThemeTranslationOverrides < ActiveRecord::Migration[8.1]
  def change
    add_column :theme_translation_overrides, :original_translation, :text, if_not_exists: true
  end
end
