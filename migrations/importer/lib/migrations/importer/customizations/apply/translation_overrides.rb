# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Apply
        class TranslationOverrides
          def initialize(dry_run:)
            @dry_run = dry_run
          end

          def call(entry)
            locale = entry["locale"].to_s
            key = entry["key"].to_s
            current = ::TranslationOverride.find_by(locale:, translation_key: key)

            if entry["reset"]
              return :unchanged if current.nil?
              ::TranslationOverride.revert!(locale, [key]) unless @dry_run
              return :changed
            end

            raise Error, "value is missing" unless entry["value"].is_a?(String)
            return :unchanged if current&.value == entry["value"]

            ::TranslationOverride.upsert!(locale, key, entry["value"]) unless @dry_run
            :changed
          end
        end
      end
    end
  end
end
