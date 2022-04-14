# frozen_string_literal: true

module Jobs
  class RegenerateSitemaps < ::Jobs::Scheduled
    every 1.hour

    def execute(_args)
      Sitemap.regenerate_sitemaps if SiteSetting.enable_sitemap?
    end
  end
end
