# frozen_string_literal: true

module Jobs
  class CleanUpApiKeysMaxLife < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      ApiKey.revoke_max_life_keys!
    end
  end
end
