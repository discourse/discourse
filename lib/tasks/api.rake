desc "generate api key if missing, return existing if already there"
task "api_key:get" => :environment do
  api_key = ApiKey.create_master_key

    puts api_key.key
end
