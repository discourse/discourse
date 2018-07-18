require_dependency 'enum_site_setting'

class S3RegionSiteSetting < EnumSiteSetting

  def self.valid_value?(val)
    valid_values.include? val
  end

  def self.values
    @values ||= valid_values.sort.map { |x| { name: "s3.regions.#{x.tr("-", "_")}", value: x } }
  end

  def self.valid_values
    [
      'ap-northeast-1',
      'ap-northeast-2',
      'ap-south-1',
      'ap-southeast-1',
      'ap-southeast-2',
      'cn-north-1',
      'eu-central-1',
      'eu-west-1',
      'eu-west-2',
      'eu-west-3',
      'sa-east-1',
      'us-east-1',
      'us-east-2',
      'us-gov-west-1',
      'us-west-1',
      'us-west-2',
    ]
  end

  def self.translate_names?
    true
  end

  private_class_method :valid_values
end
