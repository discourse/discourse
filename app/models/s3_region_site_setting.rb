class S3RegionSiteSetting
  def self.valid_value?(val)
    all_values.include? val
  end

  def self.all_values
    @all_values ||= ['', 'us-east-1', 'us-west-1', 'us-west-2', 'eu-west-1', 'ap-southeast-1', 'ap-southeast-2', 'ap-northeast-1', 'sa-east-1'].sort
  end
end