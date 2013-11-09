require_dependency 'discourse_hub'
require_dependency 'discourse_updates'

module Jobs
  class VersionCheck < Jobs::Scheduled
    recurrence { daily }

    def execute(args)
      if SiteSetting.version_checks? and (DiscourseUpdates.updated_at.nil? or DiscourseUpdates.updated_at < 1.minute.ago)
        begin
          should_send_email = (SiteSetting.new_version_emails and DiscourseUpdates.missing_versions_count and DiscourseUpdates.missing_versions_count == 0)

          json = DiscourseHub.discourse_version_check
          DiscourseUpdates.last_installed_version = Discourse::VERSION::STRING
          DiscourseUpdates.latest_version = json['latestVersion']
          DiscourseUpdates.critical_updates_available = json['criticalUpdates']
          DiscourseUpdates.missing_versions_count = json['missingVersionsCount']
          DiscourseUpdates.updated_at = Time.zone.now

          if should_send_email and json['missingVersionsCount'] > 0
            message = VersionMailer.send_notice
            Email::Sender.new(message, :new_version).send
          end
        rescue => e
          raise e unless Rails.env == 'development' # Fail version check silently in development mode
        end
      end
      true
    end

  end
end