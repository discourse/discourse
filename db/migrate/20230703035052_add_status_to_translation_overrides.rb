# frozen_string_literal: true

class AddStatusToTranslationOverrides < ActiveRecord::Migration[7.0]
  def change
    add_column :translation_overrides, :original_translation, :text
    add_column :translation_overrides, :status, :integer, null: false, default: 0
  end
end
