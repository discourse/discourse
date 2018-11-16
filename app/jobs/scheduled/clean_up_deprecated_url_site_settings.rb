module Jobs
  class CleanUpDeprecatedUrlSiteSettings < Jobs::Scheduled
    every 1.day

    def execute(args)
      Jobs::MigrateUrlSiteSettings::SETTINGS.each do |old_setting, new_setting|
        if SiteSetting.where("name = ? AND value IS NOT NULL", new_setting).exists?
          SiteSetting.public_send("#{old_setting}=", nil, warn: false)
        end
      end
    end
  end
end
