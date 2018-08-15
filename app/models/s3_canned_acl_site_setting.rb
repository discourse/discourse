require_dependency 'enum_site_setting'

class S3CannedACLSiteSetting < EnumSiteSetting

  def self.valid_value?(val)
    valid_values.include? val
  end

  def self.values
    @values ||= valid_values.map { |x| { name: x, value: x } }
  end

  def self.valid_values
    [
      'private',
      'public-read',
      'public-read-write',
      'aws-exec-read',
      'authenticated-read',
      'bucket-owner-read',
      'bucket-owner-full-control',
      'log-delivery-write',
    ]
  end

  def self.translate_names?
    false
  end

  private_class_method :valid_values
end
