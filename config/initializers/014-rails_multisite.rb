# frozen_string_literal: true

class RailsMultisite::DiscoursePatches
  def self.config
    {
      db_lookup: lambda do |env|
        env["PATH_INFO"] == "/srv/status" ? "default" : nil
      end
    }
  end
end

if Rails.configuration.multisite
  Rails.configuration.middleware.swap(
    RailsMultisite::Middleware,
    RailsMultisite::Middleware,
    RailsMultisite::DiscoursePatches.config
  )
end
