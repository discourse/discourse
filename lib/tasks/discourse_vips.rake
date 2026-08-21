# frozen_string_literal: true

require "rbconfig"

namespace :discourse_vips do
  desc "Compile the discourse-vips native helper"
  task :compile do
    root = File.expand_path("../..", __dir__)
    destination = File.join(root, "vendor", "discourse-vips", RbConfig::CONFIG.fetch("arch"))
    source_directory = File.join(root, "ext", "discourse_vips")
    make = ENV.fetch("MAKE", "make")

    sh RbConfig.ruby, "extconf.rb", chdir: source_directory
    sh make, chdir: source_directory
    sh make, "install", "destination=#{destination}", chdir: source_directory
  ensure
    if File.exist?(File.join(source_directory, "Makefile"))
      sh make, "distclean", chdir: source_directory
    end
    FileUtils.rm_rf(File.join(source_directory, "discourse_vips_helper.dSYM"))
  end
end
