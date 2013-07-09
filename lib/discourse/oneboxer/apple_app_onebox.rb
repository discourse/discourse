require_dependency 'oneboxer/handlebars_onebox'

module Oneboxer
  class AppleAppOnebox < HandlebarsOnebox

    matcher /^https?:\/\/itunes\.apple\.com\/.+$/
    favicon 'apple.png'

    # Don't masquerade as mobile
    def http_params
      {}
    end

    def template
      template_path('simple_onebox')
    end

    def parse(data)

      html_doc = Nokogiri::HTML(data)

      result = {}

      m = html_doc.at("h1")
      result[:title] = m.inner_text if m

      m = html_doc.at("h4 ~ p")
      result[:text] = m.inner_text[0..MAX_TEXT] if m

      m = html_doc.at(".product img.artwork")
      result[:image] = m['src'] if m

      result
    end

  end
end
