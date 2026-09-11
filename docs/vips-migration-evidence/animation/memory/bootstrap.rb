require "json"
require "fileutils"
require "digest"
require "active_support"
require "active_support/core_ext/object/blank"
require "pathname"
require "landlock"
require "vips"
module Rails
  def self.root
    Pathname.new(__dir__)
  end
  def self.env
    "benchmark"
  end
end
module SiteSetting
  def self.instrument_image_processing
    false
  end
end
module Discourse
  module Utils
    class CommandError < StandardError
      def initialize(message, **details)
        super(message)
      end
    end
  end
end
$LOAD_PATH.unshift(File.join(__dir__, "lib"))
require "discourse/safe_exec"
require "image_magick"
require "discourse_vips"
