# frozen_string_literal: true

# In-memory site-settings storage provider for specs, replacing the DB-backed
# one. `install!` is called from before(:suite) after plugins/themes/settings
# have loaded — ordering matters, so the call stays in rails_helper.
class TestLocalProcessProvider < SiteSettings::LocalProcessProvider
  attr_accessor :current_site

  def initialize
    super
    self.current_site = "test"
  end

  # We nuke the DB storage provider from site settings, so we yank out the
  # existing (seeded) settings and pretend they're defaults, then swap in this
  # in-memory provider.
  def self.install!
    SiteSetting.current.each do |k, v|
      # skip setting defaults for settings that are in unloaded plugins
      SiteSetting.defaults.set_regardless_of_locale(k, v) if SiteSetting.respond_to? k
    end

    # Gravatar downloads hit the network, so force the default off.
    SiteSetting.defaults.set_regardless_of_locale(:automatically_download_gravatars, false)

    SiteSetting.provider = new
  end
end
