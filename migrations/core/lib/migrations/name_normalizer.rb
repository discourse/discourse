# frozen_string_literal: true

module Migrations
  # Normalizes a username or group name for comparison the way Discourse does it
  # (Unicode NFC, then downcase), so a mention and the user or group it names match
  # however the source encoded them. Shared by the converter that types a mention
  # (`Converters::Discourse::MentionClassifier`) and the importer that maps a recorded
  # name back to a user or group (`Importer::PlaceholderResolver`), so the two sides
  # can't disagree on what counts as the same name.
  module NameNormalizer
    def self.normalize(name)
      name.unicode_normalize.downcase
    end
  end
end
