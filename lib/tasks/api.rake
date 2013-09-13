desc "generate api key if missing, return existing if already there"
task "api_key:get" => :environment do
    if SiteSetting.api_key.blank?
      SiteSetting.generate_api_key!
    end

    puts SiteSetting.api_key
end
