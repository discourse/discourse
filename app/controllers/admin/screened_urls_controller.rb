# frozen_string_literal: true

class Admin::ScreenedUrlsController < Admin::AdminController

  def index
    screened_urls = ScreenedUrl.select("domain, sum(match_count) as match_count, max(last_match_at) as last_match_at, min(created_at) as created_at").group(:domain).order('last_match_at DESC').to_a
    render_serialized(screened_urls, GroupedScreenedUrlSerializer)
  end

end
