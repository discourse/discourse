# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Apply
        # Raised during a dry run when an item depends on something this run
        # would create first. Such items are reported as changed.
        class PendingDependency < StandardError
        end
      end
    end
  end
end
