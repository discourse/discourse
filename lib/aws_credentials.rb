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
    # If s3_use_iam_profile is set (deprecated), skip explicit credentials
    # and let the SDK auto-discover (instance profile, ECS task role, etc.)
    return nil if use_iam_profile?

    # Try role assumption first
    if role_arn.present? && has_explicit_keys?
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

  def use_iam_profile?
    source.respond_to?(:s3_use_iam_profile) && source.s3_use_iam_profile
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
    source.s3_role_session_name.presence || Discourse.os_hostname
  end

  def endpoint
    nil
  end

  def http_continue_timeout
    0
  end
end
