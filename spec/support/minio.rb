# frozen_string_literal: true

# Minio (S3-compatible) server config for S3 system specs

require "minio_runner"

RSpec.configure do |config|
  config.before(:suite) do
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

      test_i = ENV["TEST_ENV_NUMBER"].to_i

      data_dir = "#{Rails.root.join("tmp/test_data_#{test_i}/minio")}"
      FileUtils.rm_rf(data_dir)
      FileUtils.mkdir_p(data_dir)
      minio_runner_config.minio_data_directory = data_dir

      minio_runner_config.minio_port = 9_000 + 2 * test_i
      minio_runner_config.minio_console_port = 9_001 + 2 * test_i
    end
  end

  config.after(:suite) { MinioRunner.stop }
end
