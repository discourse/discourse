class AddCompiledJsToTranslationOverrides < ActiveRecord::Migration
  def change
    add_column :translation_overrides, :compiled_js, :text, null: true
  end
end
