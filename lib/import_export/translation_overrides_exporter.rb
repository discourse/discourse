# frozen_string_literal: true

module ImportExport
  class TranslationOverridesExporter < BaseExporter
    def initialize()
      @export_data = { translation_overrides: [] }
    end

    def perform
      puts "Exporting all translation overrides...", ""
      export_translation_overrides

      self
    end

    def default_filename_prefix
      "translation-overrides"
    end
  end
end
