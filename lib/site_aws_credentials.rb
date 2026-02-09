# frozen_string_literal: true

require "aws_credentials"

# Credentials from SiteSetting (database)
# Only used when GlobalAwsCredentials is not configured
class SiteAwsCredentials < AwsCredentials
  def self.instance
    new(SiteSetting)
  end

  def self.configured?
    instance.configured?
  end

  def configured?
    SiteSetting.enable_s3_uploads?
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
