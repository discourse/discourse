require "aws-sdk"

class S3Helper

  def initialize(s3_bucket, tombstone_prefix=nil)
    raise Discourse::InvalidParameters.new("s3_bucket") if s3_bucket.blank?

    @s3_bucket = s3_bucket
    @tombstone_prefix = tombstone_prefix

    check_missing_site_settings
  end

  def upload(file, unique_filename, options={})
    obj = s3_bucket.object(unique_filename)
    obj.upload_file(file, options)
  end

  def remove(unique_filename, copy_to_tombstone=false)
    bucket = s3_bucket
    # copy the file in tombstone
    if copy_to_tombstone && @tombstone_prefix.present?
      bucket.object(@tombstone_prefix + unique_filename).copy_from(copy_source: "#{@s3_bucket}/#{unique_filename}")
    end
    # delete the file
    bucket.object(unique_filename).delete
  rescue Aws::S3::Errors::NoSuchKey
  end

  def update_tombstone_lifecycle(grace_period)
    return if @tombstone_prefix.blank?

    # cf. http://docs.aws.amazon.com/AmazonS3/latest/dev/object-lifecycle-mgmt.html
    s3_resource.client.put_bucket_lifecycle({
      bucket: @s3_bucket,
      lifecycle_configuration: {
        rules: [
          {
            id: "purge-tombstone",
            status: "Enabled",
            expiration: { days: grace_period },
            prefix: @tombstone_prefix
          }
        ]
      }
    })
  end

  private

    def s3_resource
      opts = { region: SiteSetting.s3_region }

      unless SiteSetting.s3_use_iam_profile
        opts[:access_key_id] = SiteSetting.s3_access_key_id
        opts[:secret_access_key] = SiteSetting.s3_secret_access_key
      end

      Aws::S3::Resource.new(opts)
    end

    def s3_bucket
      bucket = s3_resource.bucket(@s3_bucket)
      bucket.create unless bucket.exists?
      bucket
    end

    def check_missing_site_settings
      unless SiteSetting.s3_use_iam_profile
        raise Discourse::SiteSettingMissing.new("s3_access_key_id") if SiteSetting.s3_access_key_id.blank?
        raise Discourse::SiteSettingMissing.new("s3_secret_access_key") if SiteSetting.s3_secret_access_key.blank?
      end
    end

end
