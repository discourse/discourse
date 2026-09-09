require "bundler/setup"
require "active_support"
require "active_support/core_ext/object/blank"
require "pathname"
require "fileutils"
require "json"
require "digest"
require "landlock"
require "vips"
require "i18n"

module Rails
  def self.root
    Pathname.new(__dir__)
  end

  def self.env
    "benchmark"
  end
end

module SiteSetting
  class << self
    attr_accessor :strip_image_metadata
  end

  def self.instrument_image_processing
    false
  end
end

module Discourse
  class InvalidAccess < StandardError
  end

  module Utils
    class CommandError < StandardError
      def initialize(message, **details)
        super([message, details.inspect].join("\n"))
      end
    end
  end
end

I18n.enforce_available_locales = false
I18n.backend.store_translations(:en, upload: { png_to_jpg_conversion_failure_message: "JPEG conversion failed" })
raise "Production evidence requires Landlock" unless Landlock.supported?
$LOAD_PATH.unshift(File.join(__dir__, "lib"))
require "discourse/safe_exec"
require "image_magick"
require "discourse_vips"
require "geometry_commands"
require "conversion_command"
load File.join(__dir__, "probe.rb")
