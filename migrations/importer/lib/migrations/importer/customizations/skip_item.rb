# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      # Raised while handling an item to report it as skipped with a reason.
      class SkipItem < StandardError
      end
    end
  end
end
