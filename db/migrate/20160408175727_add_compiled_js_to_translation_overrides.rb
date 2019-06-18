# frozen_string_literal: true

class AddCompiledJsToTranslationOverrides < ActiveRecord::Migration[4.2]
  def change
    add_column :translation_overrides, :compiled_js, :text, null: true
  end
end
