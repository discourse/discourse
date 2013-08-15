class Admin::ScreenedUrlsController < Admin::AdminController

  def index
    screened_urls = ScreenedUrl.limit(200).order('last_match_at desc').to_a
    render_serialized(screened_urls, ScreenedUrlSerializer)
  end

end
