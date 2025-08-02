# frozen_string_literal: true

require "ruby-prof"

def profile(&blk)
  result = RubyProf.profile(&blk)
  printer = RubyProf::GraphHtmlPrinter.new(result)
  printer.print(STDOUT)
end
profile { "" } # loading profiler dependency

require File.expand_path("../../../../config/environment", __FILE__)

# warming up
SiteSetting.title
SiteSetting.enable_discourse_connect
SiteSetting.default_locale = SiteSetting.default_locale == "en" ? "zh_CN" : "en"
SiteSetting.title = SecureRandom.hex

profile { SiteSetting.title }

profile { SiteSetting.enable_discourse_connect }

profile { SiteSetting.default_locale = SiteSetting.default_locale == "en" ? "zh_CN" : "en" }

profile { SiteSetting.title = SecureRandom.hex }
