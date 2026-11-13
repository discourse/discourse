# frozen_string_literal: true

module Migrations
  module Importer
    # Changes the site settings that would reject, notify about or clean up
    # imported content, for the whole import run, and puts them back at the end.
    #
    # A setting is only put back when it still has the value the import set.
    # If an admin changed it during the run, their value stays.
    class ImportSiteSettings
      SETTINGS = {
        blocked_email_domains: "",
        min_topic_title_length: 1,
        min_post_length: 1,
        min_first_post_length: 1,
        min_personal_message_post_length: 1,
        min_personal_message_title_length: 1,
        duplicate_topic_titles: "allowed",
        disable_emails: "yes",
        max_attachment_size_kb: 102_400,
        max_image_size_kb: 102_400,
        authorized_extensions: "*",
        clean_up_inactive_users_after_days: 0,
        clean_up_unused_staged_users_after_days: 0,
        clean_up_uploads: false,
        clean_orphan_uploads_grace_period_hours: 168,
      }.freeze

      # Longer grace periods, so the site does not purge imported users and
      # uploads too early. They are not put back at the end, because the
      # imported data still needs them after the run.
      PURGE_UNACTIVATED_USERS_GRACE_PERIOD_DAYS = 60
      PURGE_DELETED_UPLOADS_GRACE_PERIOD_DAYS = 90

      def initialize
        @previous_values = nil
      end

      def apply!
        @previous_values = {}

        SETTINGS.each do |name, value|
          @previous_values[name] = SiteSetting.get(name)
          SiteSetting.set(name, value)
        end

        if SiteSetting.purge_unactivated_users_grace_period_days > 0
          SiteSetting.purge_unactivated_users_grace_period_days =
            PURGE_UNACTIVATED_USERS_GRACE_PERIOD_DAYS
        end
        SiteSetting.purge_deleted_uploads_grace_period_days =
          PURGE_DELETED_UPLOADS_GRACE_PERIOD_DAYS

        RateLimiter.disable
      end

      # Returns the number of settings that were put back, or nil when
      # {#apply!} did not run.
      def restore!
        return if @previous_values.nil?

        restored = 0
        @previous_values.each do |name, value|
          next if SiteSetting.get(name) != SETTINGS[name]

          SiteSetting.set(name, value)
          restored += 1
        end

        @previous_values = nil
        RateLimiter.enable
        restored
      end
    end
  end
end
