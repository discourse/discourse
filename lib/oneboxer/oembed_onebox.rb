require 'open-uri'
require_dependency 'oneboxer/handlebars_onebox'

module Oneboxer

  class OembedOnebox < HandlebarsOnebox

    def oembed_endpoint
      @url
    end

    def template
      template_path('oembed_onebox')
    end

    def onebox
      parsed = JSON.parse(open(oembed_endpoint).read)

      # If it's a video, just embed the iframe
      if %w(video rich).include?(parsed['type'])
        # Return a preview of the thumbnail url, since iframes don't do well on previews
        preview = nil
        preview = "<img src='#{parsed['thumbnail_url']}'>" if parsed['thumbnail_url'].present?
        return [parsed['html'], preview]
      end

      if %w(image photo).include?(parsed['type'])
        return BaseOnebox.image_html(parsed['url'] || parsed['thumbnail_url'], parsed['title'], parsed['web_page'] || @url)
      end

      parsed['original_url'] = parsed['url']
      parsed['html'] ||= parsed['abstract']
      parsed['host'] = nice_host

      Mustache.render(File.read(template), parsed)
    rescue OpenURI::HTTPError
      nil
    end

  end

end
