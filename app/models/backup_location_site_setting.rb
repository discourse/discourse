# frozen_string_literal: true

require_dependency 'enum_site_setting'

class BackupLocationSiteSetting < EnumSiteSetting
  LOCAL ||= "local"
  S3 ||= "s3"

  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      { name: "admin.backups.location.local", value: LOCAL },
      { name: "admin.backups.location.s3", value: S3 }
    ]
  end

  def self.translate_names?
    true
  end
end
