# frozen_string_literal: true

module Jobs
  class CleanUpDeprecatedUrlSiteSettings < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      ::Jobs::MigrateUrlSiteSettings::SETTINGS.each do |old_setting, new_setting|
        if SiteSetting.where("name = ? AND value IS NOT NULL", new_setting).exists?
          SiteSetting.set(old_setting, nil, warn: false)
          SiteSetting.find_by(name: old_setting).destroy!
        end
      end
    end
  end
end
