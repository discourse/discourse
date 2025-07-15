# frozen_string_literal: true

module ::Jobs
  class SyncPatronGroups < ::Jobs::Base
    def execute(args)
      ::Patreon::Patron.sync_groups_by(patreon_id: args[:patreon_id])
    end
  end
end
