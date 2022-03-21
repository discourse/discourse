# frozen_string_literal: true

# We do not run this in production cause it is intrusive and has
# potential to break stuff, it also breaks under concurrent use
# which rake:multisite_migrate uses
#
# The protection is only needed in Dev and Test

SanePatch.patch("activerecord", "~> 6.1.4") do
  module FreedomPatches
    module SafeMigrations
      if !Rails.env.production?
        require 'migration/safe_migrate'
        Migration::SafeMigrate.patch_active_record!
      end
    end
  end
end
