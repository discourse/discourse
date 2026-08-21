# frozen_string_literal: true

require "digest"
require "rbconfig"

namespace :discourse_vips do
  desc "Compile the discourse-vips native helper"
  task :compile do
    root = File.expand_path("../..", __dir__)
    destination = File.join(root, "vendor", "discourse-vips", RbConfig::CONFIG.fetch("arch"))
    source_directory = File.join(root, "ext", "discourse_vips")
    executable = File.join(destination, "discourse_vips_helper")
    signature_path = File.join(destination, "build-signature")
    lock_path = File.join(destination, "compile.lock")
    source_paths = [
      File.join(source_directory, "discourse_vips_helper.c"),
      File.join(source_directory, "extconf.rb"),
      __FILE__,
    ]
    signature =
      Digest::SHA256.hexdigest(
        [RbConfig::CONFIG.fetch("arch"), *source_paths.map { |path| File.binread(path) }].join(
          "\0",
        ),
      )
    make = ENV.fetch("MAKE", "make")

    FileUtils.mkdir_p(destination)
    File.open(lock_path, File::RDWR | File::CREAT, 0o644) do |lock|
      lock.flock(File::LOCK_EX)
      if File.executable?(executable) && File.file?(signature_path) &&
           File.read(signature_path, chomp: true) == signature
        next
      end

      sh RbConfig.ruby, "extconf.rb", chdir: source_directory
      sh make, chdir: source_directory
      sh make, "install", "destination=#{destination}", chdir: source_directory
      File.write(signature_path, signature)
    ensure
      if File.exist?(File.join(source_directory, "Makefile"))
        sh make, "distclean", chdir: source_directory
      end
      FileUtils.rm_rf(File.join(source_directory, "discourse_vips_helper.dSYM"))
    end
  end
end
