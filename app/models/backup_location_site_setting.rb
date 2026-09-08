# frozen_string_literal: true

class BackupLocationSiteSetting < EnumSiteSetting
  LOCAL = "local"
  S3 = "s3"

  class << self
    def valid_value?(val)
      values.any? { |v| v[:value] == val }
    end

    def values
      @values ||= [
        { name: "admin.backups.location.local", value: LOCAL },
        { name: "admin.backups.location.s3", value: S3 },
      ]
    end

    def translate_names?
      true
    end
  end
end
