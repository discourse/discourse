# frozen_string_literal: true

desc "generate a master api key with given description"
task "api_key:create_master", [:description] => :environment do |task, args|
  raise "Supply a description for the key" if !args[:description]
  api_key = ApiKey.create!(description: args[:description])

  puts api_key.key
end
