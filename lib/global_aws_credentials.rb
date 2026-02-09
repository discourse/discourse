# frozen_string_literal: true

require "aws_credentials"

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
    has_explicit_keys? || role_arn.present?
  end
end
