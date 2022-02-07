# frozen_string_literal: true

module Jobs

  class SuspiciousLogin < ::Jobs::Base

    def execute(args)
      if UserAuthToken.is_suspicious(args[:user_id], args[:client_ip])

        UserAuthToken.log(action: 'suspicious',
                          user_id: args[:user_id],
                          user_agent: args[:user_agent],
                          client_ip: args[:client_ip])

        ::Jobs.enqueue(:critical_user_email,
                     type: "suspicious_login",
                     user_id: args[:user_id],
                     client_ip: args[:client_ip],
                     user_agent: args[:user_agent])
      end
    end

  end

end
