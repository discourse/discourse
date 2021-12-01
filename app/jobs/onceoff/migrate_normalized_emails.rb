# frozen_string_literal: true

module Jobs
  class MigrateNormalizedEmails < ::Jobs::Onceoff
    def execute_onceoff(args)
      ::UserEmail.find_each do |user_email|
        user_email.update(normalized_email: user_email.normalize_email)
      end
    end
  end
end
