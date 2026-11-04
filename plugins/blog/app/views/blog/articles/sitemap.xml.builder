# frozen_string_literal: true

xml.instruct!
xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
  %w[/ /archive /about].each { |path| xml.url { xml.loc blog_url(path) } }
  @publications.each do |publication|
    xml.url do
      xml.loc publication.url
      xml.lastmod publication.article_updated_at.iso8601
    end
  end
end
