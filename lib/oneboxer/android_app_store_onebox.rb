require_dependency 'oneboxer/handlebars_onebox'

module Oneboxer
  class AndroidAppStoreOnebox < HandlebarsOnebox

    matcher /^https?:\/\/play\.google\.com\/.+$/
    favicon 'google_play.png'

    def template
      template_path('simple_onebox')
    end

    def parse(data)

      html_doc = Nokogiri::HTML(data)

      result = {}

      m = html_doc.at("h1.doc-banner-title")
      result[:title] = m.inner_text if m

      m = html_doc.at("div#doc-original-text")
      if m
        result[:text] = BaseOnebox.replace_tags_with_spaces(m.inner_html)
        result[:text] = result[:text][0..MAX_TEXT]
      end

      m = html_doc.at("div.doc-banner-icon img")
      result[:image] = m['src'] if m

      result
    end

  end
end
