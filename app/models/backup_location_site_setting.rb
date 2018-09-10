require_dependency 'enum_site_setting'

class BackupLocationSiteSetting < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      { name: 'admin.backups.location.local', value:  'local' },
      { name: 'admin.backups.location.s3', value:  's3' }
    ]
  end

  def self.translate_names?
    true
  end
end
