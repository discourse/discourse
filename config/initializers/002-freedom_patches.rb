# frozen_string_literal: true

require "enum_site_setting.rb"
require "locale_site_setting"
require "translation_override"
require "migration/safe_migrate"

Dir["#{Rails.root}/lib/freedom_patches/*.rb"].each do |f|
  require(f)
end
