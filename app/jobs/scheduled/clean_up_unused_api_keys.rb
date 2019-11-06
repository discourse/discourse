# frozen_string_literal: true

module Jobs

  class CleanUpUnusedApiKeys < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      ApiKey.revoke_unused_keys!
    end

  end

end
