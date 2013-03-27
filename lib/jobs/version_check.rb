require_dependency 'discourse_hub'
require_dependency 'discourse_updates'

module Jobs
  class VersionCheck < Jobs::Base

    def execute(args)
      if SiteSetting.version_checks
        begin
          json = DiscourseHub.discourse_version_check
          DiscourseUpdates.latest_version = json['latestVersion']
          DiscourseUpdates.critical_updates_available = json['criticalUpdates']
          DiscourseUpdates.missing_versions_count = json['missingVersionsCount']
        rescue => e
          raise e unless Rails.env == 'development' # Fail version check silently in development mode
        end
      end
      true
    end

  end
end