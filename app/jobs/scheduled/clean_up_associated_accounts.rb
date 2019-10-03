# frozen_string_literal: true

module Jobs

  class CleanUpAssociatedAccounts < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      UserAssociatedAccount.cleanup!
    end

  end

end
