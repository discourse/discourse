# frozen_string_literal: true

class SitemapController < ApplicationController
  layout false
  skip_before_action :preload_json, :check_xhr
  before_action :check_sitemap_enabled

  def index
    @sitemaps = Sitemap.where(enabled: true).where.not(name: Sitemap::NEWS_SITEMAP_NAME)

    render :index
  end

  def page
    index = params.require(:page)
    sitemap = Sitemap.find_by(enabled: true, name: index.to_s)
    raise Discourse::NotFound if sitemap.nil?

    @output =
      Rails
        .cache
        .fetch("sitemap/#{sitemap.name}/#{sitemap.max_page_size}", expires_in: 24.hours) do
          @topics = sitemap.topics
          render :page, content_type: "text/xml; charset=UTF-8"
        end

    render plain: @output, content_type: "text/xml; charset=UTF-8" unless performed?
  end

  def recent
    sitemap = Sitemap.touch(Sitemap::RECENT_SITEMAP_NAME)

    @output =
      Rails
        .cache
        .fetch("sitemap/recent/#{sitemap.last_posted_at.to_i}", expires_in: 1.hour) do
          @topics = sitemap.topics
          render :page, content_type: "text/xml; charset=UTF-8"
        end

    render plain: @output, content_type: "text/xml; charset=UTF-8" unless performed?
  end

  def news
    sitemap = Sitemap.touch(Sitemap::NEWS_SITEMAP_NAME)

    @output =
      Rails
        .cache
        .fetch("sitemap/news", expires_in: 5.minutes) do
          dlocale = SiteSetting.default_locale.downcase
          @locale = dlocale.gsub(/_.*/, "")
          @locale = dlocale.sub("_", "-") if @locale === "zh"
          @topics = sitemap.topics
          render :news, content_type: "text/xml; charset=UTF-8"
        end

    render plain: @output, content_type: "text/xml; charset=UTF-8" unless performed?
  end

  private

  def check_sitemap_enabled
    raise Discourse::NotFound if !SiteSetting.enable_sitemap
  end

  def build_sitemap_topic_url(slug, id)
    [Discourse.base_url, "t", slug, id].join("/")
  end
  helper_method :build_sitemap_topic_url
end
