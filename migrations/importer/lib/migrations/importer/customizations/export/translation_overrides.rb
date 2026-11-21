# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Export
        class TranslationOverrides
          def call(item)
            entry = item.slice("locale", "key", "target", "note")
            override =
              ::TranslationOverride.find_by(locale: item["locale"], translation_key: item["key"])
            return entry.merge("reset" => true) if item["reset"] || override.nil?

            entry.merge("value" => override.value)
          end
        end
      end
    end
  end
end
