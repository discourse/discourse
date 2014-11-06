require "fog"

class S3Helper

  def initialize(s3_bucket, tombstone_prefix=nil, fog=nil)
    raise Discourse::InvalidParameters.new("s3_bucket") if s3_bucket.blank?

    @s3_bucket = s3_bucket
    @tombstone_prefix = tombstone_prefix

    check_missing_site_settings

    @fog = fog || Fog::Storage.new(s3_options)
  end

  def upload(file, unique_filename, options={})
    args = {
      body: file,
      key: unique_filename,
      public: false,
    }

    args.merge!(options)

    directory = get_or_create_directory(@s3_bucket)
    directory.files.create(args)
  end

  def remove(unique_filename, copy_to_tombstone=false)
    # copy the file in tombstone
    if copy_to_tombstone && @tombstone_prefix.present?
      @fog.copy_object(unique_filename, @s3_bucket, @tombstone_prefix + unique_filename, @s3_bucket)
    end
    # delete the file
    @fog.delete_object(@s3_bucket, unique_filename)
  rescue Excon::Errors::NotFound
    # if the file cannot be found, don't raise an error
  end

  def update_tombstone_lifecycle(grace_period)
    return if @tombstone_prefix.blank?
    # cf. http://docs.aws.amazon.com/AmazonS3/latest/dev/object-lifecycle-mgmt.html
    @fog.put_bucket_lifecycle(@s3_bucket, lifecycle(grace_period))
  end

  private

    def check_missing_site_settings
      unless SiteSetting.s3_use_iam_profile
        raise Discourse::SiteSettingMissing.new("s3_access_key_id") if SiteSetting.s3_access_key_id.blank?
        raise Discourse::SiteSettingMissing.new("s3_secret_access_key") if SiteSetting.s3_secret_access_key.blank?
      end
    end

    def s3_options
      options = { provider: 'AWS', scheme: SiteSetting.scheme }

      # cf. https://github.com/fog/fog/issues/2381
      options[:path_style] = dns_compatible?(@s3_bucket, SiteSetting.use_https?)

      options[:region] = SiteSetting.s3_region unless SiteSetting.s3_region.blank?

      if SiteSetting.s3_use_iam_profile
        options.merge!(use_iam_profile: true)
      else
        options.merge!(aws_access_key_id: SiteSetting.s3_access_key_id,
                       aws_secret_access_key: SiteSetting.s3_secret_access_key)
      end

      options
    end

    def get_or_create_directory(bucket)
      directory = @fog.directories.get(bucket)
      directory = @fog.directories.create(key: bucket) unless directory
      directory
    end

    def lifecycle(grace_period)
      {
        "Rules" => [{
          "Prefix" => @tombstone_prefix,
          "Enabled" => true,
          "Expiration" => { "Days" => grace_period }
        }]
      }
    end

    # cf. https://github.com/aws/aws-sdk-core-ruby/blob/master/aws-sdk-core/lib/aws-sdk-core/plugins/s3_bucket_dns.rb#L65-L80
    def dns_compatible?(bucket_name, ssl)
      return false unless valid_subdomain?(bucket_name)
      bucket_name.match(/\./) && ssl ? false : true
    end

    def valid_subdomain?(bucket_name)
      bucket_name.size < 64 &&
      bucket_name =~ /^[a-z0-9][a-z0-9.-]+[a-z0-9]$/ &&
      bucket_name !~ /(\d+\.){3}\d+/ &&
      bucket_name !~ /[.-]{2}/
    end

end
