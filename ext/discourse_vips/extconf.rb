# frozen_string_literal: true

require "rbconfig"
require "open3"

helper = "discourse_vips_helper"
source = "discourse_vips_helper.c"
pkg_config = ENV.fetch("PKG_CONFIG", "pkg-config")

if !system(pkg_config, "--atleast-version=8.13", "vips", out: File::NULL, err: File::NULL)
  detected_version =
    begin
      output, _, status = Open3.capture3(pkg_config, "--modversion", "vips")
      status.success? && !output.strip.empty? ? output.strip : "not found"
    rescue Errno::ENOENT
      "not found"
    end
  abort "discourse-vips requires libvips >= 8.13 (found #{detected_version})"
end

read_flags =
  lambda do |flag|
    output, error, status = Open3.capture3(pkg_config, flag, "vips")
    abort "discourse-vips could not read libvips compiler flags: #{error.strip}" if !status.success?
    output.strip
  end
vips_cflags = read_flags.call("--cflags")
vips_libs = read_flags.call("--libs")

compiler = RbConfig::CONFIG.fetch("CC")
cflags = [
  ENV["CFLAGS"] || RbConfig::CONFIG["CFLAGS"],
  RbConfig::CONFIG["CPPFLAGS"],
  vips_cflags,
].compact.join(" ")
ldflags = [ENV["LDFLAGS"] || RbConfig::CONFIG["LDFLAGS"], vips_libs, "-lm"].compact.join(" ")
install = RbConfig::CONFIG.fetch("INSTALL", "install")

File.write("Makefile", <<~MAKEFILE)
    SHELL = /bin/sh
    CC = #{compiler}
    CFLAGS = #{cflags}
    LDFLAGS = #{ldflags}
    INSTALL = #{install}

    .PHONY: all install clean distclean

    all: #{helper}

    #{helper}: #{source}
	$(CC) $(CFLAGS) -o #{helper} #{source} $(LDFLAGS)

    install: all
	mkdir -p "$(destination)"
	$(INSTALL) -m 0755 #{helper} "$(destination)/#{helper}"

    clean:
	rm -f #{helper} *.o

    distclean: clean
	rm -f Makefile
  MAKEFILE
