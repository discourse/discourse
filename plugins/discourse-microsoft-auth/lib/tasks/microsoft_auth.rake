# frozen_string_literal: true

require_relative "../microsoft_auth_revoker"

desc <<~DESC
A rake task to remove microsoft as an authentication provider, log out, deactivate and remove all API keys for all
users accounts that have used Microsoft as an authentication provider.
DESC
task "microsoft_auth:revoke" => :environment do
  MicrosoftAuthRevoker.revoke
end

task "microsoft_auth:log_out_users" => :environment do
  MicrosoftAuthRevoker.log_out_users
end
