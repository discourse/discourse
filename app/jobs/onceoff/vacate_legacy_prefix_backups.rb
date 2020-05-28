# frozen_string_literal: true

module Jobs
  class VacateLegacyPrefixBackups < ::Jobs::Onceoff
    def execute_onceoff(args)
      args ||= {}
      BackupRestore::S3BackupStore.create(s3_options: args[:s3_options]).vacate_legacy_prefix if SiteSetting.backup_location == BackupLocationSiteSetting::S3
    end
  end
end
