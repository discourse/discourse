#!/usr/bin/env ruby
# frozen_string_literal: true

require "minio_runner"

class ExecuteLocalMinioS3
  def run
    begin
      start_minio
      save_old_config
      change_to_minio_settings
      puts "Press any key when done..."
      gets
      restore_old
    rescue SystemExit, Interrupt
      restore_old
      raise
    end
  end

  def start_minio
    MinioRunner.config do |minio_runner_config|
      minio_runner_config.minio_domain = ENV["MINIO_RUNNER_MINIO_DOMAIN"] || "minio.local"
      minio_runner_config.buckets =
        (
          if ENV["MINIO_RUNNER_BUCKETS"]
            ENV["MINIO_RUNNER_BUCKETS"].split(",")
          else
            ["discoursetest"]
          end
        )
      minio_runner_config.public_buckets =
        (
          if ENV["MINIO_RUNNER_PUBLIC_BUCKETS"]
            ENV["MINIO_RUNNER_PUBLIC_BUCKETS"].split(",")
          else
            ["discoursetest"]
          end
        )
    end
    puts "Starting minio..."
    MinioRunner.start
  end

  def save_old_config
    puts "Temporarily using minio config for S3. Current settings:"
    @current_s3_endpoint = puts_current(:s3_endpoint)
    @current_s3_upload_bucket = puts_current(:s3_upload_bucket)
    @current_s3_access_key_id = puts_current(:s3_access_key_id)
    @current_s3_secret_access_key = puts_current(:s3_secret_access_key)
    @current_allowed_internal_hosts = puts_current(:allowed_internal_hosts)
  end

  def change_to_minio_settings
    puts "Changing to minio settings..."
    SiteSetting.s3_upload_bucket = "discoursetest"
    SiteSetting.s3_access_key_id = MinioRunner.config.minio_root_user
    SiteSetting.s3_secret_access_key = MinioRunner.config.minio_root_password
    SiteSetting.s3_endpoint = MinioRunner.config.minio_server_url
    SiteSetting.allowed_internal_hosts =
      MinioRunner.config.minio_urls.map { |url| URI.parse(url).host }.join("|")

    puts_current(:s3_endpoint)
    puts_current(:s3_upload_bucket)
    puts_current(:s3_access_key_id)
    puts_current(:s3_secret_access_key)
    puts_current(:allowed_internal_hosts)
  end

  def restore_old
    puts "Restoring old S3 settings..."
    SiteSetting.s3_upload_bucket = @current_s3_upload_bucket
    SiteSetting.s3_access_key_id = @current_s3_access_key_id
    SiteSetting.s3_secret_access_key = @current_s3_secret_access_key
    SiteSetting.s3_endpoint = @current_s3_endpoint
    SiteSetting.allowed_internal_hosts = @current_allowed_internal_hosts

    puts_current(:s3_endpoint)
    puts_current(:s3_upload_bucket)
    puts_current(:s3_access_key_id)
    puts_current(:s3_secret_access_key)
    puts_current(:allowed_internal_hosts)
    puts "Done!"
  end

  def puts_current(setting)
    printf "%-40s %s\n", "  > Current #{setting}:", SiteSetting.send(setting)
    SiteSetting.send(setting)
  end
end

ExecuteLocalMinioS3.new.run
