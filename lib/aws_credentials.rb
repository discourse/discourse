# frozen_string_literal: true

# Base class for AWS credential resolution
# Handles role assumption, explicit keys, and SDK auto-discovery
class AwsCredentials
  attr_reader :source

  def initialize(source)
    @source = source
  end

  def configured?
    raise NotImplementedError
  end

  def region
    source.s3_region
  end

  def to_sdk_options
    opts = { region: region }
    opts[:endpoint] = endpoint if endpoint.present?
    opts[:http_continue_timeout] = http_continue_timeout
    opts[:credentials] = credentials if credentials
    opts[:use_dualstack_endpoint] = use_dualstack_endpoint
    opts
  end

  def use_dualstack_endpoint
    false
  end

  def credentials
    return @credentials if defined?(@credentials)
    @credentials = build_credentials
  end

  private

  def build_credentials
    # Try role assumption first
    if role_session_name.present? && role_arn.present? && has_explicit_keys?
      build_assume_role_credentials
    elsif has_explicit_keys?
      build_static_credentials
    end
    # nil = let AWS SDK auto-discover (instance profile, ECS task role, etc.)
  end

  def build_assume_role_credentials
    sts_client =
      Aws::STS::Client.new(
        region: region,
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
      )

    Aws::AssumeRoleCredentials.new(
      role_arn: role_arn,
      role_session_name: role_session_name,
      client: sts_client,
    )
  end

  def build_static_credentials
    Aws::Credentials.new(access_key_id, secret_access_key)
  end

  def has_explicit_keys?
    access_key_id.present? && secret_access_key.present?
  end

  def access_key_id
    source.s3_access_key_id
  end

  def secret_access_key
    source.s3_secret_access_key
  end

  def role_arn
    source.s3_role_arn
  end

  def role_session_name
    source.s3_role_session_name
  end

  def endpoint
    nil
  end

  def http_continue_timeout
    0
  end
end

# Credentials from GlobalSetting (ENV vars)
# Takes precedence over SiteAwsCredentials
class GlobalAwsCredentials < AwsCredentials
  def self.instance
    @instance ||= new(GlobalSetting)
  end

  def self.configured?
    instance.configured?
  end

  def self.to_sdk_options
    instance.to_sdk_options
  end

  def configured?
    source.s3_bucket.present? && source.s3_region.present?
  end

  def bucket
    source.s3_bucket
  end

  def backup_bucket
    source.s3_backup_bucket
  end
end

# Credentials from SiteSetting (database)
# Only used when GlobalAwsCredentials is not configured
class SiteAwsCredentials < AwsCredentials
  def self.instance
    @instance ||= new(SiteSetting)
  end

  def self.configured?
    instance.configured?
  end

  def self.to_sdk_options
    instance.to_sdk_options
  end

  def configured?
    SiteSetting.enable_s3_uploads?
  end

  def bucket
    SiteSetting.s3_upload_bucket
  end

  def backup_bucket
    SiteSetting.s3_backup_bucket
  end

  def endpoint
    SiteSetting.s3_endpoint.presence
  end

  def http_continue_timeout
    SiteSetting.s3_http_continue_timeout
  end

  def use_dualstack_endpoint
    SiteSetting.Upload.use_dualstack_endpoint
  end

  def validate!
    if access_key_id.present? || secret_access_key.present?
      if access_key_id.blank? || secret_access_key.blank?
        raise Discourse::SiteSettingMissing.new("access_key_id, secret_access_key")
      end
    end
  end
end
