# frozen_string_literal: true

module Jobs
  class RegenerateSitemaps < ::Jobs::Scheduled
    every 1.hour

    def execute(_args)
      Sitemap.regenerate_sitemaps if SiteSetting.publish_sitemaps?
    end
  end
end
