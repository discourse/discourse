# frozen_string_literal: true

module Migrations
  # Normalizes a username, group name, tag or category slug for comparison the
  # way Discourse does it (Unicode NFC, then downcase), so a mention and the
  # user or group it names match however the source encoded them. Shared by the
  # converter and the importer, so the two sides can't disagree on what counts
  # as the same name.
  module NameNormalizer
    # Lowercase final and medial sigmas are distinct identity keys in core.
    # Broader comparisons for locating markdown tokens belong in the scanner.
    def self.normalize(name)
      name.unicode_normalize.downcase
    end
  end
end
