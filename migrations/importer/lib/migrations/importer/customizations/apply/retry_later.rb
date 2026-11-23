# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Apply
        # Raised when an item may only be valid after the rest of its section is
        # applied, e.g. a setting whose validator reads other settings. The item
        # is tried once more at the end of the section.
        class RetryLater < StandardError
        end
      end
    end
  end
end
