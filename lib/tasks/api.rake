# frozen_string_literal: true

desc "find or generate a master api key with given description"
task "api_key:get_or_create_master", [:description] => :environment do |task, args|
  raise "Supply a description for the key" if !args[:description]
  api_key = ApiKey.find_or_create_by!(description: args[:description], revoked_at: nil, user_id: nil)

  puts api_key.key
end
