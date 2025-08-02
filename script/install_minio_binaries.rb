#!/usr/bin/env ruby
# frozen_string_literal: true

require "minio_runner"

ENV["MINIO_RUNNER_LOG_LEVEL"] = "DEBUG"
MinioRunner.install_binaries
