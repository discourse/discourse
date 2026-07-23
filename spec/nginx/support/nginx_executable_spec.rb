# frozen_string_literal: true

require "tmpdir"
require_relative "nginx_executable"

RSpec.describe Nginx::Support::NginxExecutable do
  around do |example|
    original_path = ENV["PATH"]
    original_bin = ENV["NGINX_BIN"]
    example.run
  ensure
    ENV["PATH"] = original_path
    ENV["NGINX_BIN"] = original_bin
  end

  def write_executable(dir, name)
    path = File.join(dir, name)
    File.write(path, "#!/bin/sh\n")
    File.chmod(0o755, path)
    path
  end

  describe ".path" do
    it "returns the first executable nginx found walking PATH in order" do
      Dir.mktmpdir do |root|
        first = File.join(root, "a")
        second = File.join(root, "b")
        FileUtils.mkdir_p(first)
        FileUtils.mkdir_p(second)
        write_executable(first, "nginx")
        write_executable(second, "nginx")

        ENV.delete("NGINX_BIN")
        ENV["PATH"] = [first, second].join(File::PATH_SEPARATOR)

        expect(described_class.path).to eq(File.join(first, "nginx"))
      end
    end

    it "skips a non-executable file named nginx and keeps walking PATH" do
      Dir.mktmpdir do |root|
        first = File.join(root, "a")
        second = File.join(root, "b")
        FileUtils.mkdir_p(first)
        FileUtils.mkdir_p(second)
        non_exec = File.join(first, "nginx")
        File.write(non_exec, "not executable")
        File.chmod(0o644, non_exec)
        real = write_executable(second, "nginx")

        ENV.delete("NGINX_BIN")
        ENV["PATH"] = [first, second].join(File::PATH_SEPARATOR)

        expect(described_class.path).to eq(real)
      end
    end

    it "returns nil when nginx is not on PATH" do
      Dir.mktmpdir do |root|
        ENV.delete("NGINX_BIN")
        ENV["PATH"] = root

        expect(described_class.path).to be_nil
      end
    end

    it "honors NGINX_BIN when it points at an executable" do
      Dir.mktmpdir do |root|
        bin = write_executable(root, "my-nginx")
        ENV["NGINX_BIN"] = bin
        ENV["PATH"] = ""

        expect(described_class.path).to eq(bin)
      end
    end

    it "returns nil when NGINX_BIN points at a non-executable" do
      Dir.mktmpdir do |root|
        bogus = File.join(root, "nope")
        File.write(bogus, "x")
        File.chmod(0o644, bogus)
        ENV["NGINX_BIN"] = bogus
        ENV["PATH"] = root

        expect(described_class.path).to be_nil
      end
    end
  end

  describe ".available?" do
    it "is false when nothing resolves" do
      Dir.mktmpdir do |root|
        ENV.delete("NGINX_BIN")
        ENV["PATH"] = root
        expect(described_class.available?).to eq(false)
      end
    end
  end
end
