require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class FlickrOnebox < BaseOnebox

    matcher /^https?\:\/\/.*\.flickr\.com\/.*$/

    def onebox

      page_html = open(@url).read
      return nil if page_html.blank?
      doc = Nokogiri::HTML(page_html)

      # Flikrs oembed just stopped returning images for no reason. Let's use opengraph instead.
      open_graph = Oneboxer.parse_open_graph(doc)

      # A site is supposed to supply all the basic og attributes, but some don't (like deviant art)
      # If it just has image and no title, embed it as an image.
      return BaseOnebox.image_html(open_graph['image'], nil, @url) if open_graph['image'].present?
      nil
    end

  end
end
